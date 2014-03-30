library('digest', quietly=TRUE)
traceDir <- '.'#Sys.getenv("TSTAT_TRACES")
if (traceDir == '') {
  traceDir <- '.'
}

memoizeDir <- paste(traceDir, 'memoize', sep='/')

.forceNoMemoize <- FALSE

# Add memoization to optimize bottleneck functions
memoize <- function (name, fn) {
  memoizedFn <- function (..., memoize=T) {
    args <- list(...)
    ## if we're not memoizing, ensure other (nested) calls are also aware
    if (!memoize || .forceNoMemoize) {
      oldValue <- .forceNoMemoize
      .forceNoMemoize <<- TRUE
      tryCatch(result <- do.call("fn", args),
               error=function (e) stop(e),
               finally=.forceNoMemoize <<- oldValue)
      return (result)
    }

    if (!file.exists(memoizeDir)) {
      stop(paste("ERROR:", memoizeDir, "does not exist."))
    }
    dirName <- paste(memoizeDir, paste('func-', name, sep=''), sep='/')
    dir.create(dirName, showWarning=FALSE)


    fileName <- paste('argsmd5-', digest(args), '.Rdata', sep='')
    fullPath <- paste(dirName, fileName, sep='/')

    tryCatch({
      if (file.exists(fullPath)) {
        # `load` will implicitly assign the loaded object to a variable of the
        # same name used when saving
        load(fullPath)
        cat(paste("DEBUG: Used memoized result for ", name, ".\n", sep=""),
            file=stderr())
        return (memoizedResult)
      }
      cat(paste("DEBUG: Did NOT use memoized result for ", name, ".\n",
                sep=""), file=stderr())
    }, error=function (err) {
      cat(paste("WARNING: Failed to load memoized result for ", name, ".\n",
                "Deleting potentially corrupt mem.", sep=""), file=stderr())
      if (file.exists(fullPath)) file.remove(fullPath)
    })

    # No memoized result, so call the original function:
    res <- do.call("fn", args)
    # This re-assignment is done just so we have a reserved name that we know
    # `load` will use (see above)
    memoizedResult <- res
    save(memoizedResult, file=fullPath, precheck=FALSE)
    return (res)
  }
  return (memoizedFn)
}
