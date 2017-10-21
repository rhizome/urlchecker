# README #

urlcheck.rb - Check a list of URLs and send email about it.

### How do I get set up? ###

* Requires the [Curb](https://github.com/taf2/curb) gem
* Copy urlcheck.yml-sample to urlcheck.yml with your own values
* URL list is a YAML array with the url and the response code you expect. 
  * All of the possible options are listed in urlcheck.yml-sample

```yaml
config:
  mailto: root
  ...
urls: [
  { url: "http://foo.invalid", code: 200 }
  ...
]
```

Tested under Ruby 2.3

### Contribution guidelines ###

Pull requests always welcome.

### Who do I talk to? ###

* eric@many9s.com