# Asserts that environment variable is set and returns its value.
# When not set, the application will exit
module.exports.assert = (envName) -> _assert process, console, envName

module.exports._assert = _assert = (process, console, envName) ->
  unless env = process.env[envName]
    console.error "Error: Environment variable '#{envName}' not set."
    process.exit(1)
  else env

module.exports.get = (envName, deflt) -> process.env[envName] or deflt
