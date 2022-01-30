import Config

config :phoenix, :json_library, Jason
config :heex_formatter, :tw_config_file, File.cwd!() <> "/config/tailwind_format.yml"
