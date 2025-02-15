# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Patch::DatabaseConfig do
  describe '#database_configuration' do
    let(:configuration) { Rails::Application::Configuration.new(Rails.root) }

    before do
      # The `AS::ConfigurationFile` calls `read` in `def initialize`
      # thus we cannot use `allow_next_instance_of`
      # rubocop:disable RSpec/AnyInstanceOf
      allow_any_instance_of(ActiveSupport::ConfigurationFile)
        .to receive(:read).with(Rails.root.join('config/database.yml')).and_return(database_yml)
      # rubocop:enable RSpec/AnyInstanceOf
    end

    shared_examples 'hash containing main: connection name' do
      it 'returns a hash containing only main:' do
        database_configuration = configuration.database_configuration

        expect(database_configuration).to match(
          "production" => { "main" => a_hash_including("adapter") },
          "development" => { "main" => a_hash_including("adapter" => "postgresql") },
          "test" => { "main" => a_hash_including("adapter" => "postgresql") }
        )
      end
    end

    shared_examples 'hash containing both main: and geo: connection names' do
      it 'returns a hash containing both main: and geo:' do
        database_configuration = configuration.database_configuration

        expect(database_configuration).to match(
          "production" => { "main" => a_hash_including("adapter"), "geo" => a_hash_including("adapter", "migrations_paths" => ["ee/db/geo/migrate", "ee/db/geo/post_migrate"], "schema_migrations_path" => "ee/db/geo/schema_migrations") },
          "development" => { "main" => a_hash_including("adapter"), "geo" => a_hash_including("adapter" => "postgresql", "migrations_paths" => ["ee/db/geo/migrate", "ee/db/geo/post_migrate"], "schema_migrations_path" => "ee/db/geo/schema_migrations") },
          "test" => { "main" => a_hash_including("adapter"), "geo" => a_hash_including("adapter" => "postgresql", "migrations_paths" => ["ee/db/geo/migrate", "ee/db/geo/post_migrate"], "schema_migrations_path" => "ee/db/geo/schema_migrations") }
        )
      end

      context 'when SKIP_POST_DEPLOYMENT_MIGRATIONS environment variable set' do
        before do
          stub_env('SKIP_POST_DEPLOYMENT_MIGRATIONS', 'true')
        end

        it 'does not include Geo post deployment migrations path' do
          database_configuration = configuration.database_configuration

          expect(database_configuration).to match(
            "production" => { "main" => a_hash_including("adapter"), "geo" => a_hash_including("adapter", "migrations_paths" => ["ee/db/geo/migrate"], "schema_migrations_path" => "ee/db/geo/schema_migrations") },
            "development" => { "main" => a_hash_including("adapter"), "geo" => a_hash_including("adapter" => "postgresql", "migrations_paths" => ["ee/db/geo/migrate"], "schema_migrations_path" => "ee/db/geo/schema_migrations") },
            "test" => { "main" => a_hash_including("adapter"), "geo" => a_hash_including("adapter" => "postgresql", "migrations_paths" => ["ee/db/geo/migrate"], "schema_migrations_path" => "ee/db/geo/schema_migrations") }
          )
        end
      end
    end

    shared_examples 'merges configuration from the external command for main: connection' do
      context 'when the external command returns valid yaml' do
        before do
          allow(Gitlab::Popen)
            .to receive(:popen)
            .and_return(["---\nmain:\n  password: 'secure password'\n", 0])
        end

        it 'merges the extra configuration' do
          database_configuration = configuration.database_configuration

          expect(database_configuration).to match(
            "production" => { "main" => a_hash_including("password" => "secure password") },
            "development" => { "main" => a_hash_including("password" => "secure password") },
            "test" => { "main" => a_hash_including("password" => "secure password") }
          )
        end
      end

      context 'when the external command returns invalid yaml' do
        before do
          allow(Gitlab::Popen)
            .to receive(:popen)
            .and_return(["---\nmain:\n  password: 'secure password\n", 0])
        end

        it 'raises an error' do
          expect { configuration.database_configuration }
            .to raise_error(
              Gitlab::Patch::DatabaseConfig::CommandExecutionError,
              %r{database.yml: Execution of `/opt/database-config.sh` generated invalid yaml}
            )
        end
      end

      context 'when the parsed external command output returns invalid hash' do
        before do
          allow(Gitlab::Popen)
            .to receive(:popen)
            .and_return(["hello", 0])
        end

        it 'raises an error' do
          expect { configuration.database_configuration }
            .to raise_error(
              Gitlab::Patch::DatabaseConfig::CommandExecutionError,
              %r{database.yml: The output of `/opt/database-config.sh` must be a Hash, String given}
            )
        end
      end

      context 'when the external command fails' do
        before do
          allow(Gitlab::Popen).to receive(:popen).and_return(["", 125])
        end

        it 'raises error' do
          expect { configuration.database_configuration }
            .to raise_error(
              Gitlab::Patch::DatabaseConfig::CommandExecutionError,
              %r{database.yml: Execution of `/opt/database-config.sh` failed}
            )
        end
      end
    end

    shared_examples 'merges configuration from the external command for both main: and geo: connections' do
      context 'when the external command returns valid yaml' do
        before do
          allow(Gitlab::Popen)
            .to receive(:popen)
            .and_return(["---\nmain:\n  password: 'secure password'\ngeo:\n  password: 'secure geo password'\n", 0])
        end

        it 'merges the extra configuration' do
          database_configuration = configuration.database_configuration

          expect(database_configuration).to match(
            "production" => { "main" => a_hash_including("password" => "secure password"), "geo" => a_hash_including("password" => "secure geo password") },
            "development" => { "main" => a_hash_including("password" => "secure password"), "geo" => a_hash_including("password" => "secure geo password") },
            "test" => { "main" => a_hash_including("password" => "secure password"), "geo" => a_hash_including("password" => "secure geo password") }
          )
        end
      end

      context 'when the external command returns invalid yaml' do
        before do
          allow(Gitlab::Popen)
            .to receive(:popen)
            .and_return(["---\nmain:\n  password: 'secure password'\ngeo:\n  password: 'secure geo password\n", 0])
        end

        it 'raises an error' do
          expect { configuration.database_configuration }
            .to raise_error(
              Gitlab::Patch::DatabaseConfig::CommandExecutionError,
              %r{database.yml: Execution of `/opt/database-config.sh` generated invalid yaml}
            )
        end
      end

      context 'when the parsed external command output returns invalid hash' do
        before do
          allow(Gitlab::Popen)
            .to receive(:popen)
            .and_return(["hello", 0])
        end

        it 'raises an error' do
          expect { configuration.database_configuration }
            .to raise_error(
              Gitlab::Patch::DatabaseConfig::CommandExecutionError,
              %r{database.yml: The output of `/opt/database-config.sh` must be a Hash, String given}
            )
        end
      end

      context 'when the external command fails' do
        before do
          allow(Gitlab::Popen).to receive(:popen).and_return(["", 125])
        end

        it 'raises error' do
          expect { configuration.database_configuration }
            .to raise_error(
              Gitlab::Patch::DatabaseConfig::CommandExecutionError,
              %r{database.yml: Execution of `/opt/database-config.sh` failed}
            )
        end
      end
    end

    context 'when config/database.yml does not contain Geo settings' do
      let(:database_yml) do
        <<-EOS
            production:
              main:
                adapter: postgresql
                encoding: unicode
                database: gitlabhq_production
                username: git
                password: "dummy password"
                host: localhost

            development:
              main:
                adapter: postgresql
                encoding: unicode
                database: gitlabhq_development
                username: postgres
                password: "dummy password"
                host: localhost
                variables:
                  statement_timeout: 15s

            test: &test
              main:
                adapter: postgresql
                encoding: unicode
                database: gitlabhq_test
                username: postgres
                password: "dummy password"
                host: localhost
                prepared_statements: false
                variables:
                  statement_timeout: 15s
        EOS
      end

      include_examples 'hash containing main: connection name'

      context 'when config/database.yml contains extra configuration through an external command' do
        let(:database_yml) do
          <<-EOS
              production:
                config_command: '/opt/database-config.sh'
                main:
                  adapter: postgresql
                  encoding: unicode
                  database: gitlabhq_production
                  username: git
                  password: "secure password"
                  host: localhost

              development:
                config_command: '/opt/database-config.sh'
                main:
                  adapter: postgresql
                  encoding: unicode
                  database: gitlabhq_development
                  username: postgres
                  password: "secure password"
                  host: localhost
                  variables:
                    statement_timeout: 15s

              test: &test
                config_command: '/opt/database-config.sh'
                main:
                  adapter: postgresql
                  encoding: unicode
                  database: gitlabhq_test
                  username: postgres
                  password:
                  host: localhost
                  prepared_statements: false
                  variables:
                    statement_timeout: 15s
          EOS
        end

        include_examples 'merges configuration from the external command for main: connection'
      end
    end

    context 'when config/database.yml contains Geo settings' do
      let(:database_yml) do
        <<-EOS
            production:
              main:
                adapter: postgresql
                encoding: unicode
                database: gitlabhq_production
                username: git
                password: "dummy password"
                host: localhost
              geo:
                adapter: postgresql
                encoding: unicode
                database: gitlabhq_geo_production
                username: git
                password: "dummy password"
                host: localhost

            development:
              main:
                adapter: postgresql
                encoding: unicode
                database: gitlabhq_development
                username: postgres
                password: "dummy password"
                host: localhost
                variables:
                  statement_timeout: 15s
              geo:
                adapter: postgresql
                encoding: unicode
                database: gitlabhq_geo_development
                username: postgres
                password: "dummy password"
                host: localhost
                variables:
                  statement_timeout: 15s

            test: &test
              main:
                adapter: postgresql
                encoding: unicode
                database: gitlabhq_test
                username: postgres
                password:
                host: localhost
                prepared_statements: false
                variables:
                  statement_timeout: 15s
              geo:
                adapter: postgresql
                encoding: unicode
                database: gitlabhq_geo_test
                username: postgres
                password:
                host: localhost
                prepared_statements: false
                variables:
                  statement_timeout: 15s
        EOS
      end

      include_examples 'hash containing both main: and geo: connection names'

      context 'when config/database.yml contains extra configuration through an external command' do
        let(:database_yml) do
          <<-EOS
              production:
                config_command: '/opt/database-config.sh'
                main:
                  adapter: postgresql
                  encoding: unicode
                  database: gitlabhq_production
                  username: git
                  password: "secure password"
                  host: localhost
                geo:
                  adapter: postgresql
                  encoding: unicode
                  database: gitlabhq_geo_production
                  username: git
                  password: "secure password"
                  host: localhost

              development:
                config_command: '/opt/database-config.sh'
                main:
                  adapter: postgresql
                  encoding: unicode
                  database: gitlabhq_development
                  username: postgres
                  password: "secure password"
                  host: localhost
                  variables:
                    statement_timeout: 15s
                geo:
                  adapter: postgresql
                  encoding: unicode
                  database: gitlabhq_geo_development
                  username: postgres
                  password: "secure password"
                  host: localhost
                  variables:
                    statement_timeout: 15s

              test: &test
                config_command: '/opt/database-config.sh'
                main:
                  adapter: postgresql
                  encoding: unicode
                  database: gitlabhq_test
                  username: postgres
                  password:
                  host: localhost
                  prepared_statements: false
                  variables:
                    statement_timeout: 15s
                geo:
                  adapter: postgresql
                  encoding: unicode
                  database: gitlabhq_geo_test
                  username: postgres
                  password:
                  host: localhost
                  prepared_statements: false
                  variables:
                    statement_timeout: 15s
          EOS
        end

        include_examples 'merges configuration from the external command for both main: and geo: connections'
      end
    end
  end
end
