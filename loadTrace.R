
source('memoize.R')
traceDir <- '.'

FullTracePath <- function (traceName) {
  return (paste(traceDir, traceName, sep="/"))
}

LoadTrace <- memoize("LoadTrace", function (filePath,
                                            absolute=FALSE,
                                            pnames=FALSE) {
# It takes a trace (kev or traceprint) and loads it into a
# data.frame. It uses an external C program to parse the traceprinter file and
# turn it into a CSV to make the loading easier.
#
# Args:
#  filePath: the path to the kev or traceprint file
#  absolute: when true the given path is absolute. When false, we must infer
#    the path from where our traces are
#  pnames:  when true, attempt to fill in the process name values for all
#     events
# Returns:
#  The trace in a data.frame
# TODO(hudon) quiet down the DEBUG msgs unless there's a flag

  if (!absolute) return (LoadTrace(FullTracePath(filePath),
                                   absolute=TRUE,
                                   pnames))
  if (pnames) return (FillPnames(LoadTrace(filePath,
                                           absolute,
                                           pnames=FALSE)))

  cat(paste("DEBUG: Loading", filePath,"...\n"), file=stderr())

  SubstrRight <- function(value, n) {
    substr(value, nchar(value) - n + 1, nchar(value))
  }

  if (missing(filePath)) {
    stop("ERROR: No filepath provided to LoadTrace function.")
  }

  # If it's not a traceprint, assume it's a kev and translate it
  header <- readLines(filePath, n=1)
  if (length(grep("TRACEPRINTER version .*$", header)) != 1) {
    cat(paste("DEBUG: Did not receive a traceprinter file, translating",
              filePath, "...\n"), file=stderr())
    tmpTrace <- tempfile(fileext=".trace")
    ret <- system(paste("traceprinter", "-n", "-f", filePath, ">", tmpTrace))
    if (ret != 0) {
      stop("ERROR: Was not given a recognizable trace OR raw .kev file")
    }
    filePath <- tmpTrace
    cat(paste("DEBUG: Traceprint created at", filePath, "\n"), file=stderr())
  }

  # NOTE: In load-trace, we are assuming that the output was of `traceprinter -n -f file`
  # where -n puts 1 event per line

  # Only use the local one if it exists, otherwise hope that it is on PATH
  procName <- 'load-trace.o'
  if (file.exists(procName)) {
    procName <- paste('./', procName, sep='')
  }

  bytesPerLine <- 32 # underestimate this
  fileSize <- file.info(filePath)$size
  lineCountOverestimate <- fileSize / bytesPerLine

  # For a list of column headers, see load-trace.c
  # pipe() allows read.csv to read the output directly rather than requiring
  # a file
  traceData <- read.csv(pipe(paste(procName, filePath)),
                        nrow=lineCountOverestimate,
                        colClasses=c(time="double",
                          cpu="integer",
                          rep("character", 2),
                          rep("integer", 3),
                          name="character",
                          ip="double",
                          rep("character", 3),
                          intnum="integer",
                          rep("character", 7),
                          rep("double", 3),
                          priority="integer",
                          policy="integer",
                          strid="character",
                          str="character"))

  # Some events are slightly out of order, so we sort by time.
  traceData <- traceData[order(traceData$time), ]
  traceData$time <- traceData$time - traceData$time[1]
  cat("DEBUG: Data loaded.\n", file=stderr())
  return (traceData)
})

LoadTracesWithPNames <- memoize("LoadTracesWithPNames", function (traceNames) {
  # Fill the pnames in parallel
  tracesWithPNames <- foreach(traceName=traceNames,
                              fileName=traceNames,
                              .combine=rbind,
                              .inorder=TRUE) %dopar% {
    data.frame(fileName=fileName, LoadTrace(traceName, pnames=T))
  }
  return (tracesWithPNames)
})

LoadTraceDiscardOutliers <- memoize("LTDiscardOutliers", function (name) {
  FilterEventsByFrequency(LoadTrace(name, pnames=TRUE))
})

DiscardLowFrequency <- function (trace) {
  FilterEventsByFrequency(trace, 100, NA, FALSE)
}

FilterEventsByFrequency <- function (trace, minFreq=NA, maxFreq=NA,
                                     rmOutliers=TRUE) {
  # Will remove events that have frequencies beyond some thresholds
  #
  # Args:
  #   trace: the trace to filter
  #   minFreq: the minimum frequency beyond which events will be discarded
  #   maxFreq: the maximum frequency beyond which events will be discarded
  #   rmOutliers: for unspecified min or max arguments, use the low or high
  #     outlier threshold defined in `boxplot.stats`
  # Returns:
  #   the filtered trace

  if (rmOutliers) {
    freqStats <- boxplot.stats(unlist(dlply(trace, class~event~pname, nrow)))
    low <- freqStats$stats[[1]]
    high <- freqStats$stats[[5]]
    if (missing(maxFreq)) maxFreq <- high
    if (missing(minFreq)) minFreq <- low
  } else if (missing(minFreq) && missing(maxFreq)) {
    message("WARNING: No minFreq or maxFreq was given, the trace was not filtered")
    return (trace)
  }

  ddply(trace, class~event~pname,
        function (procEvents) {
          numEvents <- nrow(procEvents)
          if ((!is.na(minFreq) && numEvents < minFreq) ||
              (!is.na(maxFreq) && numEvents > maxFreq)) {
            return ()
          } else {
            return (procEvents)
          }
        })
}

ConcatPNameTid <- function (trace) {
  trace$pnametid <- paste(trace$pname, trace$tid, sep='-')
  return (trace)
}

FillPnames <- function (trace) {
  message("DEBUG: Filling pnames...")
  trace$pname <- rep('', nrow(trace))

  # use the name of a PROCCREATE_NAME event to fill in the pname for matching events
  procCreates <- trace[trace$event == 'PROCCREATE_NAME',
                       c("pid", "name", "time")]

  if (nrow(procCreates) < 1) return (trace)

  pb <- txtProgressBar(0,nrow(procCreates),title="PNAME",style=3, file=stderr())
  for (i in 1:nrow(procCreates)) {
    setTxtProgressBar(pb, i)
    row <- procCreates[i, ]
    # Find the time of the next procCreate that has the same pid
    maxTime <- head(procCreates$time[procCreates$time > row$time &
                    procCreates$pid == row$pid], 1)

    matchingEvs <- !is.na(trace$pid) & trace$pid == row$pid &
      row$time <= trace$time & trace$pname == ''
    # If there is no maxTime, then the pname holds for events until the end
    # of the trace
    if (length(maxTime) > 0) {
      matchingEvs <- matchingEvs & trace$time < maxTime
    }
    trace[matchingEvs, "pname"] <- row$name
  }
  cat('\n', file=stderr())
  return (trace)
}

SplitEventIds <- function (trace) {
  trace <- trace[trace$class == 'USREVENT', ]
  # split EVENT id into its own column eventid
  trace$eventid <- sapply(strsplit(trace$event, "-"), function (x) return (x[2]))
  return (trace)
}
