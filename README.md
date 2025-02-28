# Image Optimization Suite

A comprehensive solution for optimizing images on file servers running Oracle Linux 8 (or other Linux distributions).

![License](https://img.shields.io/badge/license-MIT-blue)

## Overview

This project provides a complete toolset for optimizing image and document files on a server:

1. **Image Optimizer Script** - A bash script that processes and optimizes JPG, PNG, TIFF, GIF, and PDF files
2. **Log Parser & Report Generator** - A Python script that parses the optimization logs and generates beautiful HTML reports

The optimization process maintains image quality while significantly reducing file sizes, helping you save disk space and improve load times for applications that access these files.

## Features

### Image Optimizer

- Optimizes multiple image formats (JPG, PNG, TIFF, GIF) and PDF files
- Processes files in parallel for better performance
- Preserves directory structure
- Creates backups of original files (optional)
- Provides detailed logs of the optimization process
- Includes a dry-run mode to preview changes without modifying files
- Skips files that would become larger after optimization
- **New:** Option to install required dependencies

### Report Generator

- Parses the optimizer logs to generate comprehensive HTML reports
- Shows total space saved and percentage of reduction
- Breaks down savings by file type and directory
- Lists the top files with the highest space savings
- Includes progress bars and visual elements for better data visualization
- Provides a responsive design that works on all devices

## Screenshots

![Sample Optimization Report](/img/sample-report.png)

## Requirements

### For the Image Optimizer

- Oracle Linux 8 (or other Linux distributions)
- The following packages:
  - jpegoptim (for JPEG optimization)
  - pngquant (for PNG optimization)
  - ImageMagick (for TIFF optimization)
  - ghostscript (for PDF optimization)
  - gifsicle (for GIF optimization)

### For the Log Parser & Report Generator

- Python 3.6 or higher

## Installation

1. Clone this repository:
```bash
git clone https://github.com/yourusername/image-optimization-suite.git
cd image-optimization-suite
```

2. Install the required dependencies using the script:
```bash
./image_optimizer.sh --install-dependencies
```

3. Make the scripts executable:
```bash
chmod +x image_optimizer.sh
chmod +x log_parser.py
```

## Usage

### Running the Image Optimizer

Basic usage:
```bash
./image_optimizer.sh --source /path/to/your/files
```

Available options:
```
Usage: ./image_optimizer.sh [OPTIONS]
Optimize images in a file server (JPG, PNG, TIFF, PDF)

Options:
  -s, --source DIR          Source directory
  -b, --backup DIR          Backup directory
  -l, --log FILE            Log file (default: /var/log/image_optimizer.log)
  -t, --threads NUM         Number of parallel processes (default: 4)
  -n, --dry-run             Show what would be done without making changes
  -r, --no-recursive        Do not process subdirectories
  -i, --install-dependencies Install required dependencies
  -h, --help                Display this help and exit
```

### Generating an Optimization Report

After running the optimizer, generate an HTML report:
```bash
python3 log_parser.py --log-file /var/log/image_optimizer.log --output optimization_report.html
```

Available options:
```
Usage: log_parser.py [OPTIONS]

Options:
  -l, --log-file LOG_FILE   Path to the log file (default: /var/log/image_optimizer.log)
  -o, --output OUTPUT       Output HTML file (default: optimization_report.html)
  -t, --title TITLE         Report title (default: Image Optimization Report)
  -h, --help                Show this help message and exit
```

## Examples

### Optimizing a specific directory with backup
```bash
./image_optimizer.sh --source /var/www/html/images --backup /var/backups/images
```

### Dry run to see what would happen
```bash
./image_optimizer.sh --source /var/www/html/uploads --dry-run
```

### Generate a report with a custom title
```bash
python3 log_parser.py --log-file /var/log/image_optimizer.log --output website_images_report.html --title "Website Images Optimization Report"
```

## Scheduling Regular Optimization

You can set up a cron job to run the optimizer regularly:

```bash
# Edit crontab
crontab -e

# Add a line to run the optimizer every Sunday at 2 AM
0 2 * * 0 /path/to/image_optimizer.sh --source /path/to/your/files >> /var/log/scheduled_optimization.log 2>&1

# Add another line to generate a report after optimization (at 3 AM)
0 3 * * 0 /usr/bin/python3 /path/to/log_parser.py --output /var/www/html/reports/weekly_report.html --title "Weekly Optimization Report" >> /var/log/report_generation.log 2>&1
```

## Performance Considerations

- The script uses parallel processing to optimize multiple files simultaneously.
- You can adjust the number of parallel processes with the `--threads` option.
- For large file servers, consider increasing the thread count on powerful machines.
- Running the optimization during off-peak hours is recommended for production environments.

## Customization

### Adjusting Optimization Quality

You can modify the optimization parameters in the `image_optimizer.sh` script:

- For JPEG: Adjust the `--max=85` parameter in the `jpegoptim` command
- For PNG: Modify the `--quality=70-85` setting in the `pngquant` command
- For PDF: Change the `-dPDFSETTINGS=/ebook` parameter in the `gs` command
- For GIF: Adjust the `--optimize=3` parameter in the `gifsicle` command

Lower values result in smaller file sizes but may reduce image quality.

### Customizing the Report

The HTML report can be customized by editing the CSS styles in the `generate_html_report` function in the `log_parser.py` script.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [jpegoptim](https://github.com/tjko/jpegoptim) for JPEG optimization
- [pngquant](https://pngquant.org/) for PNG optimization
- [ImageMagick](https://imagemagick.org/) for TIFF processing
- [Ghostscript](https://www.ghostscript.com/) for PDF optimization
- [gifsicle](https://www.lcdf.org/gifsicle/) for GIF optimization
