# SchemaSherlock

Intelligent Rails model analysis and annotation tool that extends beyond traditional schema annotation to provide intelligent analysis and actionable suggestions for Rails model code quality, performance, and maintainability.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'schema_sherlock', group: :development
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install schema_sherlock

## Usage

### Basic Commands

```bash
# Analyze all models
schema_sherlock analyze

# Analyze specific model
schema_sherlock analyze User

# Override minimum usage threshold
schema_sherlock analyze --min-usage 1

# Use rake tasks instead
rake schema_sherlock:analyze
rake schema_sherlock:analyze_model[User]
```

### Configuration

Create a configuration file in your Rails application:

```ruby
# config/initializers/schema_sherlock.rb
SchemaSherlock.configure do |config|
  config.exclude_models = ['ActiveRecord::Base']  # Models to exclude from analysis
  config.min_usage_threshold = 3  # Minimum usage count for foreign key suggestions
end
```

## Features

- **Smart Association Detection**: Identifies missing associations based on foreign keys
- **Usage-Based Filtering**: Only suggests associations for frequently used foreign keys
- **Codebase Analysis**: Scans your code to track foreign key usage patterns
- **Configurable Thresholds**: Set minimum usage requirements for suggestions
- **Rails Integration**: Works via CLI, rake tasks, or directly in models

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/prateekkish/schema_sherlock.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).