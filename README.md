# README #

urlcheck.rb - Check a list of URLs and send email about it.

### How do I get set up? ###

* Ruby 1.9+
* Requires the [Curb](https://github.com/taf2/curb) gem
* Copy urlcheck.yml-sample to urlcheck.yml with your own values
* URL list is a YAML array with the url and the response code you expect. 

All of the possible options are listed in urlcheck.yml-sample:
```yaml
settings:
  mail_from: "CHANGE_ME"
  mail_to: "CHANGE_ME"
  smtp_server: smtp.example.invalid
  domain: example.invalid
urls:
  - url: "https://www.google.com"
    code: 200
  - url: "https://www.yahoo.com",
    code: 200
```

### Cron job ###
```bash
$ crontab -e 

# */5 * * * * ${HOME}/bin/urlcheck.rb 
```

### Options ###
```bash
-c --config_file     Path to YAML config file (default: ./urlcheck.yml)
```

### Contribution guidelines ###

Pull requests always welcome.

### Who do I talk to? ###

* eric@many9s.com
