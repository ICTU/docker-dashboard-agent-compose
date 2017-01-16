# Asserts that environment variable is set and returns its value.
# When not set, the application will exit
module.exports.assert = (envName) ->
  unless env = process.env[envName]
    console.error "Error: Environment variable '#{envName}' not set."
    process.exit(1)
  else env

module.exports.assertVlan = (envName) ->
  envVlan = process.env[envName]
  unless not envVlan or isValidVlan(envVlan)
    console.error "Error: Environment variable '#{envName}' should be a number between 1 and 4095 or not set at all"
    process.exit(1)
  else envVlan

isValidVlan = (envVlan) ->
  if envVlan.match /^(409[0-5]|40[0-8][0-9]|[0-3][0-9][0-9][0-9]|[0-9][0-9][0-9]|[0-9][0-9]|[1-9])$/
    true
  else
    false
