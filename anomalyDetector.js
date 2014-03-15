var fs = require('fs');
var brain = require('brain'),
    _ = require('lodash');


var runNetwork = function (trainingInputs, input) {
  var net = new brain.NeuralNetwork();

  var outputs = [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1];

  var trainingSet = trainingInputs.map(function (input, i) {
    return {input: input, output: [outputs[i]]};
  });

  console.log(trainingSet);

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
  'hexacopter-hil-full-while.kev.csv',
  'hexacopter-hil-half-while.kev.csv',
  //'hexacopter-hil-fifo-ls-02.kev.csv'
  'hexacopter-hil-clean-10.kev.csv'
];

var trainingSet = {};
var cb = _.after(traces.length, function () {

  orderedTrainingSet = [];
  traces.forEach(function (name) {
    orderedTrainingSet.push(trainingSet[name]);
  });
  // use the last trace as input (not for training);
  var input = orderedTrainingSet.splice(orderedTrainingSet.length - 1)[0];
  console.log('training inputs', orderedTrainingSet, 'input:', input);
  runNetwork(orderedTrainingSet, input);
});

traces.forEach(function (trace) {

  fs.readFile(trace, {encoding: 'utf8'}, function (err, data) {
    if (err) throw err;

    var stats = {};
    var targetEvs = ["BUFFER", "TIME", "PROCCREATE_NAME",
                     "THCREATE", "THREADY", "THRECEIVE", "THSIGWAITINFO", "PROCTHREAD_NAME",
                     "THNANOSLEEP", "THREPLY", "THRUNNING", "THCONDVAR", "THJOIN", "TRACE_EVENT/01", "MSG_SENDV/11",
                      "SND_MESSAGE", "REC_MESSAGE", "MSG_RECEIVEV/14",
                      "MSG_REPLYV/15","REPLY_MESSAGE","REC_PULSE", "SND_PULSE_EXE","EVENT-2",
                      "EVENT-0","CONNECT_CLIENT_INFO/42",
                      "SYNC_CONDVAR_SIGNAL/83","SYNC_CONDVAR_SIG/83","SYNC_CONDVAR_WAIT/82",
                      "MSG_READV/16","THWAITPAGE",
                      "MSG_WRITEV/17","TIMER_TIMEOUT/75","SIGNAL_WAITINFO/32",
                      "EVENT-1","MSG_INFO/19",
                      "MSG_CURRENT/10","EVENT-3",
                      "MSG_DELIVER_EVENT/21","MSG_SENDVNC/12","THSEND",
                      "MSG_ERROR/13","MSG_ERROR","CONNECT_ATTACH/39",
                      "PATHMGR_OPEN","CONNECT_DETACH/40","CONNECT_FLAGS/43",
                      "SYNC_MUTEX_LOCK/80","THMUTEX","SYNC_MUTEX_UNLOCK/81"];


    var lines = data.split('\n');
    lines.splice(0, 1);
    lines.splice(lines.length - 1);
    var eventCount = lines.length;

    var events = lines.map(function (line) {
      var token = line.split(',')[4];
      return token.substring(1, token.length - 1);
    });

    targetEvs.forEach(function (targetEv) {
      var foundTargets = events.filter(function (ev) {
        return ev === targetEv;
      });
      stats[targetEv] = foundTargets.length / eventCount;
    });

    trainingSet[trace] = stats;
    cb();
  });
});



