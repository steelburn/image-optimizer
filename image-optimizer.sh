#!/bin/bash

# image_optimizer.sh - A script to optimize images in a file server
# Supports JPG, PNG, TIFF, PDF, and GIF files
# For Oracle Linux 8

# Configuration variables - modify these as needed
SOURCE_DIR="/home/steelburn/imageopt/backup"    # Directory containing the images to optimize
LOG_FILE="/home/steelburn/imageopt/image-optimizer/logs/image_optimizer.log"
BACKUP_DIR="/home/steelburn/imageopt/image-optimizer/backup"        # Optional: backup original files before optimization
MAX_THREADS=4                       # Number of parallel processes
DRY_RUN=false                       # Set to true to show what would be done without making changes
RECURSIVE=true                      # Process subdirectories recursively
VERBOSE=false                       # Enable verbose output
ENABLE_BACKUP=true                  # Enable or disable backup functionality

# Function to handle log file rotation
rotate_log_file() {
    if [ -f "$LOG_FILE" ]; then
        local timestamp=$(date -r "$LOG_FILE" '+%Y%m%d_%H%M%S')
        local rotated_log="${LOG_FILE%.*}_$timestamp.${LOG_FILE##*.}"
        mv "$LOG_FILE" "$rotated_log" || { echo "ERROR: Failed to rotate log file"; exit 1; }
        echo "Old log file renamed to: $rotated_log"
    fi
    touch "$LOG_FILE" || { echo "ERROR: Failed to create new log file"; exit 1; }
}

# Call the log rotation function at the start of the script
rotate_log_file

# Function to log messages
log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$message" >> "$LOG_FILE"
    if $VERBOSE; then
        echo "$message"
    fi
}

# Function to check if required tools are installed
check_requirements() {
    local missing_tools=()
    
    # Check for basic tools
    for tool in find xargs basename dirname mktemp; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    # Check for image processing tools
    if ! command -v jpegoptim &> /dev/null; then
        missing_tools+=("jpegoptim")
    fi
    
    if ! command -v pngquant &> /dev/null; then
        missing_tools+=("pngquant")
    fi
    
    if ! command -v convert &> /dev/null; then
        missing_tools+=("imagemagick")
    fi
    
    if ! command -v gs &> /dev/null; then
        missing_tools+=("ghostscript")
    fi
    
    # If any tools are missing, instruct on how to install them
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log "ERROR: The following required tools are missing: ${missing_tools[*]}"
        log "Please install them using: sudo dnf install ${missing_tools[*]}"
        log "For some tools, you might need to enable EPEL repository:"
        log "sudo dnf install epel-release"
        log "sudo dnf install jpegoptim pngquant ImageMagick ghostscript"
        exit 1
    fi
}

# Function to install required dependencies
install_dependencies() {
    log "Installing required dependencies..."
    sudo dnf install -y epel-release
    sudo dnf install -y jpegoptim pngquant ImageMagick ghostscript gifsicle
    log "Dependencies installed successfully."
}

# Function to create backup of a file
backup_file() {
    if $ENABLE_BACKUP && [ -n "$BACKUP_DIR" ]; then
        local file="$1"
        local rel_path="${file#$SOURCE_DIR/}"
        local backup_path="$BACKUP_DIR/$rel_path"
        local backup_dir="$(dirname "$backup_path")"
        
        if [ ! -d "$backup_dir" ]; then
            mkdir -p "$backup_dir"
        fi
        
        cp "$file" "$backup_path"
        log "Backed up: $file -> $backup_path"
    fi
}

# Function to optimize JPEG files
optimize_jpeg() {
    local file="$1"
    local filesize_before=$(stat -c%s "$file")
    local temp_file=$(mktemp)

    if $DRY_RUN; then
        log "Would optimize JPEG: $file"
    else
        backup_file "$file"
        jpegoptim --strip-all --max=85 --stdout "$file" > "$temp_file" 2>> "$LOG_FILE"
        
        # Only replace if the optimized file is smaller
        if [ -f "$temp_file" ] && [ -s "$temp_file" ]; then
            local temp_size=$(stat -c%s "$temp_file")
            if [ $temp_size -lt $filesize_before ]; then
                mv "$temp_file" "$file"
                local saved=$(( (filesize_before - temp_size) * 100 / filesize_before ))
                log "Optimized JPEG: $file (saved $saved%)"
            else
                log "Skipped JPEG: $file (optimized version not smaller)"
                rm "$temp_file"
            fi
        else
            log "Failed to optimize JPEG: $file"
            [ -f "$temp_file" ] && rm "$temp_file"
        fi
    fi
}

# Function to optimize PNG files
optimize_png() {
    local file="$1"
    local filesize_before=$(stat -c%s "$file")
    local temp_file=$(mktemp)
    
    if $DRY_RUN; then
        log "Would optimize PNG: $file"
    else
        backup_file "$file"
        pngquant --force --skip-if-larger --strip --quality=70-85 --output "$temp_file" "$file" >> "$LOG_FILE" 2>&1
        
        # Only replace if the optimized file is smaller and the optimization was successful
        if [ -f "$temp_file" ] && [ -s "$temp_file" ]; then
            local temp_size=$(stat -c%s "$temp_file")
            if [ $temp_size -lt $filesize_before ]; then
                mv "$temp_file" "$file"
                local saved=$(( (filesize_before - temp_size) * 100 / filesize_before ))
                log "Optimized PNG: $file (saved $saved%)"
            else
                log "Skipped PNG: $file (optimized version not smaller)"
                rm "$temp_file"
            fi
        else
            log "Failed to optimize PNG: $file"
            [ -f "$temp_file" ] && rm "$temp_file"
        fi
    fi
}

# Function to optimize TIFF files
optimize_tiff() {
    local file="$1"
    local filesize_before=$(stat -c%s "$file")
    local temp_file=$(mktemp --suffix=.tiff)
    
    if $DRY_RUN; then
        log "Would optimize TIFF: $file"
    else
        backup_file "$file"
        convert "$file" -compress LZW "$temp_file" >> "$LOG_FILE" 2>&1
        
        # Only replace if the optimized file is smaller and the optimization was successful
        if [ -f "$temp_file" ] && [ -s "$temp_file" ]; then
            local temp_size=$(stat -c%s "$temp_file")
            if [ $temp_size -lt $filesize_before ]; then
                mv "$temp_file" "$file"
                local saved=$(( (filesize_before - temp_size) * 100 / filesize_before ))
                log "Optimized TIFF: $file (saved $saved%)"
            else
                log "Skipped TIFF: $file (optimized version not smaller)"
                rm "$temp_file"
            fi
        else
            log "Failed to optimize TIFF: $file"
            [ -f "$temp_file" ] && rm "$temp_file"
        fi
    fi
}

# Function to optimize PDF files
optimize_pdf() {
    local file="$1"
    local filesize_before=$(stat -c%s "$file")
    local temp_file=$(mktemp --suffix=.pdf)

    if $DRY_RUN; then
        log "Would optimize PDF: $file"
    else
        backup_file "$file"
        gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/ebook \
           -dNOPAUSE -dQUIET -dBATCH \
           -sOutputFile="$temp_file" "$file" >> "$LOG_FILE" 2>&1

        # Only replace if the optimized file is smaller
        if [ -f "$temp_file" ] && [ -s "$temp_file" ]; then
            local temp_size=$(stat -c%s "$temp_file")
            if [ $temp_size -lt $filesize_before ]; then
                mv "$temp_file" "$file"
                local saved=$(( (filesize_before - temp_size) * 100 / filesize_before ))
                log "Optimized PDF: $file (saved $saved%)"
            else
                log "Skipped PDF: $file (optimized version not smaller)"
                rm "$temp_file"
            fi
        else
            log "Failed to optimize PDF: $file"
            [ -f "$temp_file" ] && rm "$temp_file"
        fi
    fi
}

# Function to optimize GIF files
optimize_gif() {
    local file="$1"
    local filesize_before=$(stat -c%s "$file")
    local temp_file=$(mktemp --suffix=.gif)
    
    if $DRY_RUN; then
        log "Would optimize GIF: $file"
    else
        backup_file "$file"
        gifsicle --optimize=3 --output "$temp_file" "$file" >> "$LOG_FILE" 2>&1
        
        # Only replace if the optimized file is smaller and the optimization was successful
        if [ -f "$temp_file" ] && [ -s "$temp_file" ]; then
            local temp_size=$(stat -c%s "$temp_file")
            if [ $temp_size -lt $filesize_before ]; then
                mv "$temp_file" "$file"
                local saved=$(( (filesize_before - temp_size) * 100 / filesize_before ))
                log "Optimized GIF: $file (saved $saved%)"
            else
                log "Skipped GIF: $file (optimized version not smaller)"
                rm "$temp_file"
            fi
        else
            log "Failed to optimize GIF: $file"
            [ -f "$temp_file" ] && rm "$temp_file"
        fi
    fi
}

# Function to process a file based on its extension
process_file() {
    local file="$1"
    
    # Skip files that are not regular files or are not readable
    if [ ! -f "$file" ] || [ ! -r "$file" ]; then
        return
    fi
    
    # Skip files that are empty or very small
    local filesize=$(stat -c%s "$file")
    if [ $filesize -lt 1024 ]; then
        log "Skipping small file: $file"
        return
    fi
    
    # Process based on file extension
    case "${file,,}" in
        *.jpg|*.jpeg)
            optimize_jpeg "$file"
            ;;
        *.png)
            optimize_png "$file"
            ;;
        *.tif|*.tiff)
            optimize_tiff "$file"
            ;;
        *.pdf)
            optimize_pdf "$file"
            ;;
        *.gif)
            optimize_gif "$file"
            ;;
        *)
            # Skip files with unsupported extensions
            ;;
    esac
}

# Function to find and process files
find_and_process() {
    local find_args=("$SOURCE_DIR")
    
    # Add recursive option if enabled
    if ! $RECURSIVE; then
        find_args+=("-maxdepth" "1")
    fi
    
    # Add file type filters
    find_args+=("(" "-name" "*.jpg" "-o" "-name" "*.jpeg" "-o" "-name" "*.png" "-o" 
                 "-name" "*.tif" "-o" "-name" "*.tiff" "-o" "-name" "*.pdf" "-o" "-name" "*.gif" ")")
    
    # Add type filter to only process regular files
    find_args+=("-type" "f")
    
    # Export functions and variables for xargs
    export -f log backup_file optimize_jpeg optimize_png optimize_tiff optimize_pdf optimize_gif process_file
    export SOURCE_DIR BACKUP_DIR ENABLE_BACKUP DRY_RUN LOG_FILE VERBOSE
    
    # Use xargs to process files in parallel
    find "${find_args[@]}" -print0 | xargs -0 -P $MAX_THREADS -I{} bash -c 'process_file "$@"' _ {}
}

# Main execution logic
main() {
    log "Starting image optimization process"
    log "Source directory: $SOURCE_DIR"
    log "Recursive: $RECURSIVE"
    log "Dry run: $DRY_RUN"

    # Validate source directory
    if [ ! -d "$SOURCE_DIR" ]; then
        log "ERROR: Source directory does not exist: $SOURCE_DIR"
        exit 1
    fi

    # Check for required tools
    check_requirements

    # Create backup directory if specified
    if [ -n "$BACKUP_DIR" ] && [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR" || { log "ERROR: Failed to create backup directory: $BACKUP_DIR"; exit 1; }
        log "Created backup directory: $BACKUP_DIR"
    fi

    # Process files
    find_and_process

    log "Image optimization process completed"
}

# Script usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Optimize images in a file server (JPG, PNG, TIFF, PDF, GIF)"
    echo
    echo "Options:"
    echo "  -s, --source DIR          Source directory (default: $SOURCE_DIR)"
    echo "  -b, --backup DIR          Backup directory (default: $BACKUP_DIR)"
    echo "  -l, --log FILE            Log file (default: $LOG_FILE)"
    echo "  -t, --threads NUM         Number of parallel processes (default: $MAX_THREADS)"
    echo "  -n, --dry-run             Show what would be done without making changes"
    echo "  -r, --no-recursive        Do not process subdirectories"
    echo "  -v, --verbose             Enable verbose output"
    echo "  -i, --install-dependencies Install required dependencies"
    echo "  --default                 Run with default configuration variables"
    echo "  --no-backup               Disable backup functionality"
    echo "  -h, --help                Display this help and exit"
    echo
    echo "Configuration Variables:"
    echo "  SOURCE_DIR: $SOURCE_DIR"
    echo "  BACKUP_DIR: $BACKUP_DIR"
    echo "  LOG_FILE: $LOG_FILE"
    echo "  MAX_THREADS: $MAX_THREADS"
    echo "  DRY_RUN: $DRY_RUN"
    echo "  RECURSIVE: $RECURSIVE"
    echo "  VERBOSE: $VERBOSE"
    echo "  ENABLE_BACKUP: $ENABLE_BACKUP"
    echo
    echo "Examples:"
    echo "  $0 --default"
    echo "  $0 -s /images --no-backup --verbose"
}

# Check if no arguments are passed
if [[ "${BASH_SOURCE[0]}" == "${0}" && $# -eq 0 ]]; then
    echo "No parameters provided. Showing help:"
    usage
    exit 0
fi

# Parse command-line arguments if this script is called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--source)
                SOURCE_DIR="$2"
                shift 2
                ;;
            -b|--backup)
                BACKUP_DIR="$2"
                shift 2
                ;;
            -l|--log)
                LOG_FILE="$2"
                shift 2
                ;;
            -t|--threads)
                MAX_THREADS="$2"
                shift 2
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -r|--no-recursive)
                RECURSIVE=false
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -i|--install-dependencies)
                install_dependencies
                exit 0
                ;;
            --default)
                # Use default configuration variables
                log "Running with default configuration variables."
                shift
                ;;
            --no-backup)
                ENABLE_BACKUP=false
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Start the optimization process
    main "$@"
fi
