Deployment

Export MongoDB Realm app:
```shell
realm-cli export --app-id=dev-icarus-mzcsi --output=backend --include-hosting
```
Import MongoDB Realm app:
```shell
realm-cli import --path backend --include-hosting
```

Folder description:
* `backend` - MongoDB Realm app downloaded using `realm-cli export`
* `google-princeton` - Google Apps Script downloaded using `clasp clone`
* `shinyapp` - R Shiny app for data visualization
* `webserver` - web server for data downloads

Reference:
* https://docs.mongodb.com/realm/deploy/export-realm-app
* https://github.com/google/clasp#clone
* https://docs.mongodb.com/realm/functions/upload-external-dependencies/
