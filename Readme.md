# Off-Call - PagerDuty Utilities

Collection of utilities to work with PagerDuty activities.

It include the following commands:

 * `report` - Generate report of PagerDuty activity for a specific time
   range.
 * `incidents2csv` - Export listing of incidents into CSV format.

## Installation

```
$ bundle install
```

## Configuration

The utilities are configured through environment variables. A file named
`.env` is read to set environment variables when the command is run.

```
$ cp .env.sample .env
$ vi .env
```

The most important variables to set are:

 * **PAGERDUTY_SUBDOMAIN** The `pagerduty.com` subdomain to use as API
   endpoint.
 * **PAGERDUTY_USER* The username to use for authentication.
 * **PAGERDUTY_PASSWORD* The password to use for authentication.
 * **SERVICES** The services defined in PagerDuty to operate on.


## report

Generate report of PagerDuty activity for a specific time range.

Usage:

```
$ bundle exec bin/report
Summary for PXXXXXX,PYYYYYY from 2012-05-16 12:00:00 +0000 to 2012-05-23 15:23:52 +0000
+-----------------+-------+
| Key             | Count |
+-----------------+-------+
| Test incident   | 1     |
+-----------------+-------+
...

$ SINCE="Last Week" UNTIL=Now bundle exec bin/report 
...

$ SERVICES=PXXXXXX,PYYYYYY bundle SINCE="Last Week" UNTIL=Now bundle exec bin/report
...report for specific services only...
```

## incidents2csv

Usage:

```
$ bundle exec bin/incidents2csv
Found 12 matching incidents.
```

The file `incidents.csv` in the current direction will contain the
exported CSV data.
