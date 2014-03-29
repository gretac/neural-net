var fs = require('fs');
var brain = require('brain'),
    _ = require('lodash');


var runNetwork = function (trainingInputs, input) {
  var net = new brain.NeuralNetwork();

  var outputs = [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1];

  var trainingSet = trainingInputs.map(function (input, i) {
    return {input: input, output: [outputs[i]]};
  });

  // console.log(trainingSet);

  var trainingRes = net.train(trainingSet);

  console.log('training complete. results:', trainingRes);
  if (trainingRes.error > 0.1 && trainingRes.iterations > 10000) {
    console.log('training went wrong. The data might be too noisy');
  }

  var output = net.run(input);

  console.log(output);
};

var traces = [
  'hexacopter-hil-clean-01.kev.csv',
  'hexacopter-hil-clean-02.kev.csv',
  'hexacopter-hil-clean-03.kev.csv',
  'hexacopter-hil-clean-04.kev.csv',
  'hexacopter-hil-clean-05.kev.csv',
  'hexacopter-hil-clean-06.kev.csv',
  'hexacopter-hil-clean-07.kev.csv',
  'hexacopter-hil-clean-08.kev.csv',
  'hexacopter-hil-clean-09.kev.csv',
  'hexacopter-hil-fifo-ls-01.kev.csv',
  'hexacopter-hil-fifo-ls-sporadic.kev.csv',
  // 'hexacopter-hil-full-while.kev.csv',
  // 'hexacopter-hil-half-while.kev.csv',
  'hexacopter-hil-fifo-ls-02.kev.csv'
  // 'hexacopter-hil-clean-10.kev.csv'
];

var trainingSet = {};
var cb = _.after(traces.length, function () {

  orderedTrainingSet = [];
  traces.forEach(function (name) {
    orderedTrainingSet.push(trainingSet[name]);
  });
  // use the last trace as input (not for training);
  var input = orderedTrainingSet.splice(orderedTrainingSet.length - 1)[0];
  // console.log('training inputs', orderedTrainingSet, 'input:', input);
  runNetwork(orderedTrainingSet, input);
});

var uniq_pairs = [];

traces.forEach(function (trace) {

  fs.readFile(trace, {encoding: 'utf8'}, function (err, data) {
    if (err) throw err;

    var stats = {};

    var lines = data.split('\n');
    lines.splice(0, 1);
    lines.splice(lines.length - 1);
    var eventCount = lines.length;

    var events = lines.map(function (line) {
      var event_token = line.split(',')[4];
      var pname_token = line.split(',')[28];

      event_token = event_token.substring(1, event_token.length - 1);
      pname_token = pname_token.substring(1, pname_token.length - 1);

      // token = token.substring(1, token.length - 1);
      var token = event_token + '-' + pname_token;

      if (_.indexOf(uniq_pairs, token) < 0) uniq_pairs.push(token);
      // console.log(token);
      // console.log(uniq_pairs.length);
      return token;
    });

    // console.log(uniq_pairs);

    // targetEvs.forEach(function (targetEv) {
    //   var foundTargets = events.filter(function (ev) {
    //     return ev === targetEv;
    //   });
    //   // console.log(foundTargets.length);
    //   stats[targetEv] = foundTargets.length / eventCount;
    // });

    uniq_pairs.forEach(function (targetEv) {
      var foundTargets = events.filter(function (ev) {
        return ev === targetEv;
      });
      // console.log(foundTargets.length);
      stats[targetEv] = foundTargets.length / eventCount;
    });

    trainingSet[trace] = stats;
    cb();
  });
});



