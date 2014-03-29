var util = require('util');
var fs = require('fs');
var _ = require('lodash');

var uniq_pairs = [];
var trainingSet = {};

var traces = {
  'hexacopter-hil-clean-01.kev.csv' : 'clean',
  'hexacopter-hil-clean-02.kev.csv' : 'clean',
  'hexacopter-hil-clean-03.kev.csv' : 'clean',
  'hexacopter-hil-clean-04.kev.csv' : 'clean',
  'hexacopter-hil-clean-05.kev.csv' : 'clean',
  'hexacopter-hil-clean-06.kev.csv' : 'clean',
  'hexacopter-hil-clean-07.kev.csv' : 'clean',
  'hexacopter-hil-clean-08.kev.csv' : 'clean',
  'hexacopter-hil-clean-09.kev.csv' : 'clean',
  // 'hexacopter-hil-fifo-ls-01.kev.csv' : 'anomaly',
  // 'hexacopter-hil-fifo-ls-sporadic.kev.csv' : 'anomaly',
  // 'hexacopter-hil-full-while.kev.csv' : 'anomaly',
  // 'hexacopter-hil-half-while.kev.csv' : 'anomaly',
  'hexacopter-hil-fifo-ls-02.kev.csv' : 'anomaly',
  'hexacopter-hil-clean-10.kev.csv' : 'clean'
};

var runNet = function () {
  console.log(trainingSet);

  var netInput = trainingSet['hexacopter-hil-clean-10.kev.csv'];
  delete trainingSet['hexacopter-hil-clean-10.kev.csv'];

  // Create a SOM of four (width X height) nodes.
  // It will expect traces.length items to be submitted for training.
  var som = require('som').create({features: uniq_pairs, iterationCount: _.size(traces), width: 2, height: 2});

  //initialize SOM with default distance function (euclidean)
  som.init({});

  //begin training SOM
  _.forEach(trainingSet, function (val, key) {
    console.log("Trace: " + key);
    console.log("Class of the trace: " + traces[key]);
    som.train(traces[key], val);
  });

  console.log('SOM', util.inspect(som, false, 8));

  var result = som.bestMatchingUnit(netInput);
  console.log(util.inspect(result, false, 8));
};

var cb = _.after(_.size(traces), function () {
  runNet();
});

_.forEach(traces, function (tclass, trace) {
  fs.readFile(trace, {encoding: 'utf8'}, function (err, data) {
    if (err) throw err;
    var stats = {};

    var lines = data.split('\n');
    lines.splice(0, 1);
    lines.splice(lines.length - 1);
    var eventCount = lines.length;

    var events = lines.map(function (line) {
      var token = line.split(',')[4];
      // var event_token = line.split(',')[4];
      // var pname_token = line.split(',')[28];

      // event_token = event_token.substring(1, event_token.length - 1);
      // pname_token = pname_token.substring(1, pname_token.length - 1);

      token = token.substring(1, token.length - 1);
      // var token = event_token + '-' + pname_token;

      if (_.indexOf(uniq_pairs, token) < 0) uniq_pairs.push(token);
      return token;
    });

    uniq_pairs.forEach(function (targetEv) {
      var foundTargets = events.filter(function (ev) {
        return ev === targetEv;
      });
      // console.log(foundTargets.length);
      stats[targetEv] = foundTargets.length;
    });

    trainingSet[trace] = stats;
    cb();
  });
});

// fs.readFile('eventData.json', 'utf8', function (err, data) {
//   if (err) throw err;
//   trainingSet = JSON.parse(data);
//   _.forEach(trainingSet, function (evCntDict) {
//     _.forEach(evCntDict, function (cnt, ev) {
//       if (_.indexOf(uniq_pairs, ev) < 0) uniq_pairs.push(ev);
//     });
//   });

//   runNet();
// });
