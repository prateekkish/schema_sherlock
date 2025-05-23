# Changelog

## [0.1.0] - 2025-01-23

### Added
- Smart association detection based on foreign keys
- Usage-based filtering with configurable thresholds
- Codebase scanning for foreign key usage patterns
- CLI interface with analyze command
- Configurable minimum usage threshold

### Features
- Detects missing `belongs_to` associations from foreign key columns
- Validates foreign key references against existing tables
- Tracks foreign key usage across Rails application
- Filters suggestions based on actual usage frequency
- Provides detailed analysis reports
- Supports complex foreign key types (integer, bigint, UUID, string)
- Smart table and model inference

## [0.1.1] - 2025-01-24

### Features
- Adds recommendations for missing indices for foreign keys

### Bugs and improvements
- Make analysis 80% fast
- Safe load models to avoid break constraint errors