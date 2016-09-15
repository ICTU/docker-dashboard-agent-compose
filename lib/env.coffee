# Asserts that environment variable is set and returns its value.
# When not set, the application will exit
module.exports.assert = (envName) ->
  unless env = process.env[envName]
    console.error "Error: Environment variable '#{envName}' not set."
    process.exit(1)
  else env
