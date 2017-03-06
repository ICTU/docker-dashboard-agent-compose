_ = require 'lodash'

module.exports =
  #
  # Takes in a depends_on list or object and always outputs a depends_on object.
  # When transformation form a list to an object is required it will add each
  # list item as a key on the new object and set the condition parameter.
  #
  transformDependsOnToObject: (depends_on, condition = 'service_started') ->
    if depends_on
      if depends_on.length?
        _.zipObject depends_on, depends_on.map -> condition: condition
      else depends_on
    else null
