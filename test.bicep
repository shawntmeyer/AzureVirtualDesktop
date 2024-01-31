var tags = {
  user: 'stmeyer'
  created: '2018-01-01'
}
var jsonString = json(tags)
var tagsString = string(tags)
var newValue = replace(tagsString, '\\', '')

output object object = tags

output string string = string(tags)
output newValue string = newValue
