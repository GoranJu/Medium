# frozen_string_literal: true

module SecretsManagement
  class OpenbaoTestSetup
    SERVER_ADDRESS = '127.0.0.1:9800'
    PROXY_ADDRESS = '127.0.0.1:9900'
    SERVER_URI_TO_PING = "http://#{SERVER_ADDRESS}/v1/sys/health".freeze
    PROXY_URI_TO_PING = "http://#{PROXY_ADDRESS}/v1/sys/mounts".freeze

    class << self
      def install_dir
        File.join('tmp', 'tests', 'openbao')
      end

      def bin_path
        File.join(install_dir, 'bin', 'bao')
      end

      def build_openbao_binary
        if File.exist?(bin_path)
          # In CI, this should also be true if the cache has been warmed up
          puts 'OpenBao binary already built. Skip building...'
          true
        else
          puts 'OpenBao binary not yet built. Building...'
          system("make clean build > /dev/null", chdir: install_dir)
        end
      end

      def start_server_and_proxy
        return if services_running?

        puts "Starting up OpenBao services..."

        # rubocop:disable Layout/LineLength -- long command
        server_pid = Process.spawn(
          %(#{bin_path} server -dev -dev-root-token-id=root -dev-listen-address="#{SERVER_ADDRESS}" -dev-no-store-token),
          [:out, :err] => "log/test-openbao-server.log")
        # rubocop:enable Layout/LineLength

        at_exit do
          Process.kill("TERM", server_pid)
        end

        wait_for_ready(SERVER_URI_TO_PING, :server)

        proxy_pid = Process.spawn(
          %(#{bin_path} proxy -config=ee/spec/support/helpers/secrets_management/test_proxy.hcl),
          [:out, :err] => "log/test-openbao-proxy.log")

        at_exit do
          Process.kill("TERM", proxy_pid)
        end

        # This also confirms if the proxy has successfully authenticated with the server
        wait_for_ready(PROXY_URI_TO_PING, :proxy)
      end

      def services_running?
        ping_success?(SERVER_URI_TO_PING) && ping_success?(PROXY_URI_TO_PING)
      rescue Errno::ECONNREFUSED
        false
      end

      def ping_success?(uri)
        uri = URI(uri)
        response = Net::HTTP.get_response(uri)
        response.code.to_i == 200
      end

      def wait_for_ready(uri, service)
        Timeout.timeout(15) do
          loop do
            begin
              break if ping_success?(uri)

              raise "OpenBao #{service} responded with #{response.code}."
            rescue Errno::ECONNREFUSED
              puts "Waiting for OpenBao #{service} to start..."
            end
            sleep 2
          end
          puts "OpenBao #{service} started..."
        end
      rescue Timeout::Error
        raise "Timed out waiting for OpenBao #{service} to start."
      end
    end
  end
end
