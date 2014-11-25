require('coffee-script/register');

// Agenda scheduler settings
var agenda = new require('agenda')({
    db: {
        address: process.env.npm_package_config_mongo_url || "localhost:27017/bkxcrawler"
    },
    defaultConcurrency: 1,
    processEvery: "5 seconds"
});
function graceful() {
    console.log("Stopping gracefully..");
    agenda.stop(function() {
        process.exit(0);
    });
}
process.on('SIGTERM', graceful);
process.on('SIGINT' , graceful);

// Load all crawlers
var crawlers = require('require-all')({ dirname: __dirname + '/crawlers', filter: /(.+)\.(js)?$/});
for(crawler in crawlers) {
    console.log('Loading crawler ' + crawler + '..');
    crawlers[crawler](agenda);
}

// Start work
agenda.start()
console.log("\nScheduler started")


var express = require('express');
var agendaUI = require('agenda-ui');

var app = express();
app.use('/agenda-ui', agendaUI(agenda, {poll: 1000}));

var server = app.listen(3001, function() {

});

agenda.jobs({}, function(err, jobs) {
   console.log(jobs)
});
