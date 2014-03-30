source('loadTrace.R')
library('kohonen')
library('plyr')

evs <- c("BUFFER","TIME","PROCCREATE_NAME", "THCREATE","THREADY",
         "THRECEIVE", "THSIGWAITINFO","PROCTHREAD_NAME","THNANOSLEEP",
         "THREPLY","THRUNNING","THCONDVAR", "THJOIN","TRACE_EVENT/01",
         "MSG_SENDV/11", "SND_MESSAGE","REC_MESSAGE",
         "MSG_RECEIVEV/14", "MSG_REPLYV/15","REPLY_MESSAGE",
         "REC_PULSE", "0x00000044","SND_PULSE_EXE","EVENT-2",
         "0x00000029","EVENT-0","CONNECT_CLIENT_INFO/42",
         "SYNC_CONDVAR_SIGNAL/83", "SYNC_CONDVAR_SIG/83",
         "SYNC_CONDVAR_WAIT/82", "MSG_READV/16","THWAITPAGE",
         "0x0000002d", "MSG_WRITEV/17","TIMER_TIMEOUT/75",
         "SIGNAL_WAITINFO/32", "EVENT-1","0x00000049",
         "MSG_INFO/19", "MSG_CURRENT/10","EVENT-3", "0x0000002e",
         "MSG_DELIVER_EVENT/21","MSG_SENDVNC/12","THSEND",
         "MSG_ERROR/13","MSG_ERROR","CONNECT_ATTACH/39",
         "PATHMGR_OPEN","CONNECT_DETACH/40","CONNECT_FLAGS/43",
         "SYNC_MUTEX_LOCK/80","THMUTEX","SYNC_MUTEX_UNLOCK/81")

GetEventTotals <- memoize('GetEventTotals', function (traceName) {
  trace <- LoadTrace(traceName)
  ret <- sapply(evs, function (ev) {
    targets <- trace[trace$event == ev, ]
    as.integer(nrow(targets))
  })
  return (ret)
})

traces <- c('hexacopter-hil-clean-01.trace',
           'hexacopter-hil-clean-02.trace',
           'hexacopter-hil-clean-03.trace',
           'hexacopter-hil-clean-04.trace',
           'hexacopter-hil-clean-05.trace',
           'hexacopter-hil-clean-06.trace',
           #'hexacopter-hil-fifo-ls-01.trace',
           #'hexacopter-hil-fifo-ls-02.trace',
           'hexacopter-hil-half-while.trace')
           #'hexacopter-hil-full-while.trace')

testTraces <- c('hexacopter-hil-clean-07.trace',
                'hexacopter-hil-clean-08.trace',
                'hexacopter-hil-clean-09.trace',
                 'hexacopter-hil-fifo-ls-02.trace',
                'hexacopter-hil-fifo-ls-sporadic.trace')

GetTraceEvents <- memoize("GetTraceEvents", function (traceNames) {
  trainingData <- matrix(data=0, nrow=length(traceNames), ncol=length(evs))
  colnames(trainingData) <- evs
  for (i in 1:length(traceNames)) {
    trainingData[i, ] <- GetEventTotals(traceNames[[i]])
  }
  return (trainingData)
})


RunNet <- function () {
  Xtraining <- GetTraceEvents(traces)
  Xtest <- GetTraceEvents(testTraces)
  som.traces <- som(Xtraining, grid=somgrid(2, 3, "hexagonal"))
  som.prediction <- predict(som.traces, newdata=Xtest, trainX=Xtraining,
                            trainY=c(1,1,1,1,1,1, 2))
  return (som.prediction)

}


RunNetClean <- function () {
  Xtraining <- GetTraceEvents(traces)
  Xtest <- GetTestTraceEventsClean()
  som.traces <- som(Xtraining, grid=somgrid(3, 3, "hexagonal"))
  som.prediction <- predict(som.traces, newdata=Xtest, trainX=Xtraining,
                            trainY=c(1,1,1,1,1,1,2,2,3,3))
  return (som.prediction)

}
