pid_file = "./test_proxy_pidfile"

api_proxy {
  use_auto_auth_token = "force"
}

vault {
  address = "http://127.0.0.1:9800"

  retry {
    num_retries = 5
  }
}

listener "tcp" {
  address = "127.0.0.1:9900"
  tls_disable = true
}

auto_auth {
  method {
    type = "token_file"

    config = {
      token_file_path = "ee/spec/support/helpers/secrets_management/openbao_auth_token"
    }
  }
}
