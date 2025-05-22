# AnnotatePlus

Intelligent Rails model analysis and annotation tool that extends beyond traditional schema annotation to provide intelligent analysis and actionable suggestions for Rails model code quality, performance, and maintainability.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'annotate_plus', group: :development
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install annotate_plus

## Usage

### Basic Commands

```bash
# Analyze all models
annotate_plus analyze

# Analyze specific model
annotate_plus analyze User

# Run analysis in interactive mode
annotate_plus analyze User --interactive

# Save analysis results to file
annotate_plus analyze --output analysis_report.json

# Override minimum usage threshold
annotate_plus analyze --min-usage 1

# Use rake tasks instead
rake annotate_plus:analyze
rake annotate_plus:analyze_model[User]
```

### Configuration

Create a configuration file in your Rails application:

```ruby
# config/initializers/annotate_plus.rb
AnnotatePlus.configure do |config|
  config.analyze_query_logs = true
  config.suggest_indexes = true
  config.detect_unused_associations = true
  config.annotation_position = :top # or :bottom
  config.exclude_models = ['ActiveRecord::Base']
  config.min_usage_threshold = 3 # minimum usage count for suggestions
end
```

## Features

- **Smart Association Detection**: Identifies missing associations based on foreign keys
- **Usage-Based Filtering**: Only suggests associations for frequently used foreign keys
- **Codebase Analysis**: Scans your code to track foreign key usage patterns
- **Configurable Thresholds**: Set minimum usage requirements for suggestions
- **Rails Integration**: Works via CLI, rake tasks, or directly in models
- **Performance Optimization**: Recommends indexes and caching strategies
- **Interactive Mode**: Allows selective application of suggestions

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/prateekkish/annotate_plus.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).