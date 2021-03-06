##
## function: gsva
## purpose: main function of the package which estimates activity
##          scores for each given gene-set

setGeneric("gsva", function(expr, gset.idx.list, ...) standardGeneric("gsva"))

setMethod("gsva", signature(expr="SummarizedExperiment", gset.idx.list="GeneSetCollection"),
          function(expr, gset.idx.list, annotation,
  method=c("gsva", "ssgsea", "zscore", "plage"),
  kcdf=c("Gaussian", "Poisson", "none"),
  abs.ranking=FALSE,
  min.sz=1,
  max.sz=Inf,
  parallel.sz=1L, 
  mx.diff=TRUE,
  tau=switch(method, gsva=1, ssgsea=0.25, NA),
  ssgsea.norm=TRUE,
  verbose=TRUE,
  BPPARAM=SerialParam(progressbar=verbose))
{
  method <- match.arg(method)
  kcdf <- match.arg(kcdf)

  if (length(assays(expr)) == 0L)
    stop("The input SummarizedExperiment object has no assay data.")

  if (missing(annotation))
    annotation <- names(assays(se))[1]
  else {
    if (!is.character(annotation))
      stop("The 'annotation' argument must contain a character string.")
    annotation <- annotation[1]

    if (!annotation %in% names(assays(se)))
      stop(sprintf("Assay %s not found in the input SummarizedExperiment object.", annotation))
  }

  se <- expr
  expr <- assays(se)[[annotation]]

  ## filter genes according to verious criteria,
  ## e.g., constant expression
  expr <- .filterFeatures(expr, method)

  if (nrow(expr) < 2)
    stop("Less than two genes in the input ExpressionSet object\n")

  annotpkg <- metadata(se)$annotation
  if (!is.null(annotpkg) && length(annotpkg) > 0 && is.character(annotpkg) && annotpkg != "") {
    if (!annotpkg %in% installed.packages())
      stop(sprintf("Please install the nnotation package %s", annotpkg))

    if (verbose)
      cat("Mapping identifiers between gene sets and feature names\n")

    ## map gene identifiers of the gene sets to the features in the chip
    ## Biobase::annotation() is necessary to disambiguate from the
    ## 'annotation' argument
    mapped.gset.idx.list <- mapIdentifiers(gset.idx.list,
                                           AnnoOrEntrezIdentifier(annotpkg))
    mapped.gset.idx.list <- geneIds(mapped.gset.idx.list) 
  } else {
    mapped.gset.idx.list <- gset.idx.list
    if (verbose) {
      cat("No annotation package name available in the input 'SummarizedExperiment' object 'expr'.",
          "Attempting to directly match identifiers in 'expr' to gene sets.", sep="\n")
    }
  }

  ## map to the actual features for which expression data is available
  mapped.gset.idx.list <- lapply(mapped.gset.idx.list,
                                 function(x, y) na.omit(match(x, y)),
                                 rownames(se))

  if (length(unlist(mapped.gset.idx.list, use.names=FALSE)) == 0)
    stop("No identifiers in the gene sets could be matched to the identifiers in the expression data.")

  ## remove gene sets from the analysis for which no features are available
  ## and meet the minimum and maximum gene-set size specified by the user
  mapped.gset.idx.list <- filterGeneSets(mapped.gset.idx.list,
                                         min.sz=max(1, min.sz),
                                         max.sz=max.sz)

  if (!missing(kcdf)) {
    if (kcdf == "Gaussian") {
      rnaseq <- FALSE
      kernel <- TRUE
    } else if (kcdf == "Poisson") {
      rnaseq <- TRUE
      kernel <- TRUE
    } else
      kernel <- FALSE
  }

  eSco <- .gsva(expr, mapped.gset.idx.list, method, kcdf, rnaseq, abs.ranking,
                parallel.sz, mx.diff, tau, kernel, ssgsea.norm, verbose, BPPARAM) 

  rval <- SummarizedExperiment(assays=SimpleList(es=eSco),
                               colData=colData(se),
                               metadata=metadata(se))
  metadata(rval)$annotation <- NULL

  rval
})

setMethod("gsva", signature(expr="SummarizedExperiment", gset.idx.list="list"),
          function(expr, gset.idx.list, annotation,
  method=c("gsva", "ssgsea", "zscore", "plage"),
  kcdf=c("Gaussian", "Poisson", "none"),
  abs.ranking=FALSE,
  min.sz=1,
  max.sz=Inf,
  parallel.sz=1L, 
  mx.diff=TRUE,
  tau=switch(method, gsva=1, ssgsea=0.25, NA),
  ssgsea.norm=TRUE,
  verbose=TRUE,
  BPPARAM=SerialParam(progressbar=verbose))
{
  method <- match.arg(method)
  kcdf <- match.arg(kcdf)

  if (length(assays(expr)) == 0L)
    stop("The input SummarizedExperiment object has no assay data.")

  if (missing(annotation))
    annotation <- names(assays(se))[1]
  else {
    if (!is.character(annotation))
      stop("The 'annotation' argument must contain a character string.")
    annotation <- annotation[1]

    if (!annotation %in% names(assays(se)))
      stop(sprintf("Assay %s not found in the input SummarizedExperiment object.", annotation))
  }

  se <- expr
  expr <- assays(se)[[annotation]]

  ## filter genes according to verious criteria,
  ## e.g., constant expression
  expr <- .filterFeatures(expr, method)

  if (nrow(expr) < 2)
    stop("Less than two genes in the input ExpressionSet object\n")

  ## map to the actual features for which expression data is available
  mapped.gset.idx.list <- lapply(gset.idx.list,
                                 function(x, y) na.omit(match(x, y)),
                                 rownames(se))

  if (length(unlist(mapped.gset.idx.list, use.names=FALSE)) == 0)
    stop("No identifiers in the gene sets could be matched to the identifiers in the expression data.")

  ## remove gene sets from the analysis for which no features are available
  ## and meet the minimum and maximum gene-set size specified by the user
  mapped.gset.idx.list <- filterGeneSets(mapped.gset.idx.list,
                                         min.sz=max(1, min.sz),
                                         max.sz=max.sz)

  if (!missing(kcdf)) {
    if (kcdf == "Gaussian") {
      rnaseq <- FALSE
      kernel <- TRUE
    } else if (kcdf == "Poisson") {
      rnaseq <- TRUE
      kernel <- TRUE
    } else
      kernel <- FALSE
  }

  eSco <- .gsva(expr, mapped.gset.idx.list, method, kcdf, rnaseq, abs.ranking,
                parallel.sz, mx.diff, tau, kernel, ssgsea.norm, verbose, BPPARAM) 

  rval <- SummarizedExperiment(assays=SimpleList(es=eSco),
                               colData=colData(se),
                               metadata=metadata(se))
  metadata(rval)$annotation <- NULL

  rval
})

setMethod("gsva", signature(expr="ExpressionSet", gset.idx.list="list"),
          function(expr, gset.idx.list, annotation,
  method=c("gsva", "ssgsea", "zscore", "plage"),
  kcdf=c("Gaussian", "Poisson", "none"),
  abs.ranking=FALSE,
  min.sz=1,
  max.sz=Inf,
  parallel.sz=1L, 
  mx.diff=TRUE,
  tau=switch(method, gsva=1, ssgsea=0.25, NA),
  ssgsea.norm=TRUE,
  verbose=TRUE,
  BPPARAM=SerialParam(progressbar=verbose))
{
  method <- match.arg(method)
  kcdf <- match.arg(kcdf)

  eset <- expr
  expr <- exprs(eset)
  ## filter genes according to verious criteria,
  ## e.g., constant expression
  expr <- .filterFeatures(expr, method)

  if (nrow(expr) < 2)
    stop("Less than two genes in the input ExpressionSet object\n")

  ## map to the actual features for which expression data is available
  mapped.gset.idx.list <- lapply(gset.idx.list,
                                 function(x, y) na.omit(match(x, y)),
                                 featureNames(eset))

  if (length(unlist(mapped.gset.idx.list, use.names=FALSE)) == 0)
    stop("No identifiers in the gene sets could be matched to the identifiers in the expression data.")

  ## remove gene sets from the analysis for which no features are available
  ## and meet the minimum and maximum gene-set size specified by the user
  mapped.gset.idx.list <- filterGeneSets(mapped.gset.idx.list,
                                         min.sz=max(1, min.sz),
                                         max.sz=max.sz)

  if (!missing(kcdf)) {
    if (kcdf == "Gaussian") {
      rnaseq <- FALSE
      kernel <- TRUE
    } else if (kcdf == "Poisson") {
      rnaseq <- TRUE
      kernel <- TRUE
    } else
      kernel <- FALSE
  }

  eSco <- .gsva(expr, mapped.gset.idx.list, method, kcdf, rnaseq, abs.ranking,
                parallel.sz, mx.diff, tau, kernel, ssgsea.norm, verbose, BPPARAM) 

  rval <- new("ExpressionSet", exprs=eSco, phenoData=phenoData(eset),
              experimentData=experimentData(eset), annotation="")

  rval
})

setMethod("gsva", signature(expr="ExpressionSet", gset.idx.list="GeneSetCollection"),
          function(expr, gset.idx.list, annotation,
  method=c("gsva", "ssgsea", "zscore", "plage"),
  kcdf=c("Gaussian", "Poisson", "none"),
  abs.ranking=FALSE,
  min.sz=1,
  max.sz=Inf,
  parallel.sz=1L, 
  mx.diff=TRUE,
  tau=switch(method, gsva=1, ssgsea=0.25, NA),
  ssgsea.norm=TRUE,
  verbose=TRUE,
  BPPARAM=SerialParam(progressbar=verbose))
{
  method <- match.arg(method)
  kcdf <- match.arg(kcdf)

  eset <- expr
  expr <- exprs(eset)
  ## filter genes according to verious criteria,
  ## e.g., constant expression
  expr <- .filterFeatures(expr, method)

  if (nrow(expr) < 2)
    stop("Less than two genes in the input ExpressionSet object\n")

  annotpkg <- Biobase::annotation(eset)
  if (length(annotpkg) > 0 && annotpkg != "") {
    if (!annotpkg %in% installed.packages())
      stop(sprintf("Please install the nnotation package %s", annotpkg))

    if (verbose)
      cat("Mapping identifiers between gene sets and feature names\n")

    ## map gene identifiers of the gene sets to the features in the chip
    ## Biobase::annotation() is necessary to disambiguate from the
    ## 'annotation' argument
    mapped.gset.idx.list <- mapIdentifiers(gset.idx.list,
                                           AnnoOrEntrezIdentifier(annotpkg))
    mapped.gset.idx.list <- geneIds(mapped.gset.idx.list) 
  } else {
    mapped.gset.idx.list <- gset.idx.list
    if (verbose) {
      cat("No annotation package name available in the input 'ExpressionSet' object 'expr'.",
        "Attempting to directly match identifiers in 'expr' to gene sets.", sep="\n")
    }
  }

  ## map to the actual features for which expression data is available
  tmp <- lapply(mapped.gset.idx.list,
                function(x, y) na.omit(match(x, y)),
                featureNames(eset))
  names(tmp) <- names(mapped.gset.idx.list)

  ## remove gene sets from the analysis for which no features are available
  ## and meet the minimum and maximum gene-set size specified by the user
  mapped.gset.idx.list <- filterGeneSets(tmp,
                                         min.sz=max(1, min.sz),
                                         max.sz=max.sz)

  if (!missing(kcdf)) {
    if (kcdf == "Gaussian") {
      rnaseq <- FALSE
      kernel <- TRUE
    } else if (kcdf == "Poisson") {
      rnaseq <- TRUE
      kernel <- TRUE
    } else
      kernel <- FALSE
  }

  eSco <- .gsva(expr, mapped.gset.idx.list, method, kcdf, rnaseq, abs.ranking,
                parallel.sz, mx.diff, tau, kernel, ssgsea.norm, verbose, BPPARAM)

  rval <- new("ExpressionSet", exprs=eSco, phenoData=phenoData(eset),
              experimentData=experimentData(eset), annotation="")

  rval
})

setMethod("gsva", signature(expr="matrix", gset.idx.list="GeneSetCollection"),
          function(expr, gset.idx.list, annotation,
  method=c("gsva", "ssgsea", "zscore", "plage"),
  kcdf=c("Gaussian", "Poisson", "none"),
  abs.ranking=FALSE,
  min.sz=1,
  max.sz=Inf,
  parallel.sz=1L, 
  mx.diff=TRUE,
  tau=switch(method, gsva=1, ssgsea=0.25, NA),
  ssgsea.norm=TRUE,
  verbose=TRUE,
  BPPARAM=SerialParam(progressbar=verbose))
{
  method <- match.arg(method)
  kcdf <- match.arg(kcdf)

  ## filter genes according to verious criteria,
  ## e.g., constant expression
  expr <- .filterFeatures(expr, method)

  if (nrow(expr) < 2)
    stop("Less than two genes in the input expression data matrix\n")

  ## map gene identifiers of the gene sets to the features in the matrix
  mapped.gset.idx.list <- gset.idx.list
  if (!missing(annotation)) {
    if (verbose)
      cat("Mapping identifiers between gene sets and feature names\n")

    mapped.gset.idx.list <- mapIdentifiers(gset.idx.list,
                                           AnnoOrEntrezIdentifier(annotation))
  }
  
  ## map to the actual features for which expression data is available
  tmp <- lapply(geneIds(mapped.gset.idx.list),
                                 function(x, y) na.omit(match(x, y)),
                                 rownames(expr))
  names(tmp) <- names(mapped.gset.idx.list)

  if (length(unlist(tmp, use.names=FALSE)) == 0)
    stop("No identifiers in the gene sets could be matched to the identifiers in the expression data.")

  ## remove gene sets from the analysis for which no features are available
  ## and meet the minimum and maximum gene-set size specified by the user
  mapped.gset.idx.list <- filterGeneSets(tmp,
                                         min.sz=max(1, min.sz),
                                         max.sz=max.sz)

  if (!missing(kcdf)) {
    if (kcdf == "Gaussian") {
      rnaseq <- FALSE
      kernel <- TRUE
    } else if (kcdf == "Poisson") {
      rnaseq <- TRUE
      kernel <- TRUE
    } else
      kernel <- FALSE
  }

  rval <- .gsva(expr, mapped.gset.idx.list, method, kcdf, rnaseq, abs.ranking,
                parallel.sz, mx.diff, tau, kernel, ssgsea.norm,
                verbose, BPPARAM)

  rval
})

setMethod("gsva", signature(expr="matrix", gset.idx.list="list"),
          function(expr, gset.idx.list, annotation,
  method=c("gsva", "ssgsea", "zscore", "plage"),
  kcdf=c("Gaussian", "Poisson", "none"),
  abs.ranking=FALSE,
  min.sz=1,
  max.sz=Inf,
  parallel.sz=1L, 
  mx.diff=TRUE,
  tau=switch(method, gsva=1, ssgsea=0.25, NA),
  ssgsea.norm=TRUE,
  verbose=TRUE,
  BPPARAM=SerialParam(progressbar=verbose))
{
  method <- match.arg(method)
  kcdf <- match.arg(kcdf)

  ## filter genes according to verious criteria,
  ## e.g., constant expression
  expr <- .filterFeatures(expr, method)

  if (nrow(expr) < 2)
    stop("Less than two genes in the input expression data matrix\n")

  mapped.gset.idx.list <- lapply(gset.idx.list,
                                 function(x ,y) na.omit(match(x, y)),
                                 rownames(expr))

  if (length(unlist(mapped.gset.idx.list, use.names=FALSE)) == 0)
    stop("No identifiers in the gene sets could be matched to the identifiers in the expression data.")

  ## remove gene sets from the analysis for which no features are available
  ## and meet the minimum and maximum gene-set size specified by the user
  mapped.gset.idx.list <- filterGeneSets(mapped.gset.idx.list,
                                         min.sz=max(1, min.sz),
                                         max.sz=max.sz)

  if (!missing(kcdf)) {
    if (kcdf == "Gaussian") {
      rnaseq <- FALSE
      kernel <- TRUE
    } else if (kcdf == "Poisson") {
      rnaseq <- TRUE
      kernel <- TRUE
    } else
      kernel <- FALSE
  }

  rval <- .gsva(expr, mapped.gset.idx.list, method, kcdf, rnaseq, abs.ranking,
                parallel.sz, mx.diff, tau, kernel, ssgsea.norm, verbose, BPPARAM)

  rval
})

.gsva <- function(expr, gset.idx.list,
  method=c("gsva", "ssgsea", "zscore", "plage"),
  kcdf=c("Gaussian", "Poisson", "none"),
  rnaseq=FALSE,
  abs.ranking=FALSE,
  parallel.sz=1L,
  mx.diff=TRUE,
  tau=1,
  kernel=TRUE,
  ssgsea.norm=TRUE,
  verbose=TRUE,
  BPPARAM=SerialParam(progressbar=verbose)) {

	if (length(gset.idx.list) == 0) {
		stop("The gene set list is empty! Filter may be too stringent.")
	}

  parallel.sz <- as.integer(parallel.sz)
  if (parallel.sz < 1L)
    parallel.sz <- 1L
	
  ## because we keep the argument 'parallel.sz' for backwards compatibility
  ## we need to harmonize it with the contents of BPPARAM
  if (parallel.sz > 1L && class(BPPARAM) == "SerialParam") {
    BPPARAM=MulticoreParam(progressbar=verbose, workers=parallel.sz, tasks=100)
  } else if (parallel.sz == 1L && class(BPPARAM) != "SerialParam") {
    parallel.sz <- bpnworkers(BPPARAM)
  } else if (parallel.sz > 1L && class(BPPARAM) != "SerialParam") {
    bpworkers(BPPARAM) <- parallel.sz
  }

  if (class(BPPARAM) != "SerialParam" && verbose)
    cat(sprintf("Setting parallel calculations through a %s back-end\nwith workers=%d and tasks=100.\n",
                    class(BPPARAM), parallel.sz))

  if (method == "ssgsea") {
	  if(verbose)
		  cat("Estimating ssGSEA scores for", length(gset.idx.list),"gene sets.\n")

    return(ssgsea(expr, gset.idx.list, alpha=tau, parallel.sz=parallel.sz,
                  normalization=ssgsea.norm, verbose=verbose, BPPARAM=BPPARAM))
  }

  if (method == "zscore") {
    if (rnaseq)
      stop("rnaseq=TRUE does not work with method='zscore'.")

	  if(verbose)
		  cat("Estimating combined z-scores for", length(gset.idx.list), "gene sets.\n")

    return(zscore(expr, gset.idx.list, parallel.sz, verbose, BPPARAM=BPPARAM))
  }

  if (method == "plage") {
    if (rnaseq)
      stop("rnaseq=TRUE does not work with method='plage'.")

	  if(verbose)
		  cat("Estimating PLAGE scores for", length(gset.idx.list),"gene sets.\n")

    return(plage(expr, gset.idx.list, parallel.sz, verbose, BPPARAM=BPPARAM))
  }

	if(verbose)
		cat("Estimating GSVA scores for", length(gset.idx.list),"gene sets.\n")
	
	n.samples <- ncol(expr)
	n.genes <- nrow(expr)
	n.gset <- length(gset.idx.list)
	
	es.obs <- matrix(NaN, n.gset, n.samples, dimnames=list(names(gset.idx.list),colnames(expr)))
	colnames(es.obs) <- colnames(expr)
	rownames(es.obs) <- names(gset.idx.list)
	
	es.obs <- compute.geneset.es(expr, gset.idx.list, 1:n.samples,
                               rnaseq=rnaseq, abs.ranking=abs.ranking,
                               parallel.sz=parallel.sz,
                               mx.diff=mx.diff, tau=tau, kernel=kernel,
                               verbose=verbose, BPPARAM=BPPARAM)
	
	colnames(es.obs) <- colnames(expr)
	rownames(es.obs) <- names(gset.idx.list)

	es.obs
}


compute.gene.density <- function(expr, sample.idxs, rnaseq=FALSE, kernel=TRUE){
	n.test.samples <- ncol(expr)
	n.genes <- nrow(expr)
	n.density.samples <- length(sample.idxs)
	
  gene.density <- NA
  if (kernel) {
	  A = .C("matrix_density_R",
			as.double(t(expr[ ,sample.idxs, drop=FALSE])),
			as.double(t(expr)),
			R = double(n.test.samples * n.genes),
			n.density.samples,
			n.test.samples,
			n.genes,
      as.integer(rnaseq))$R
	
	  gene.density <- t(matrix(A, n.test.samples, n.genes))
  } else {
    gene.density <- t(apply(expr, 1, function(x, sample.idxs) {
                                     f <- ecdf(x[sample.idxs])
                                     f(x)
                                   }, sample.idxs))
    gene.density <- log(gene.density / (1-gene.density))
  }

	return(gene.density)	
}

compute.geneset.es <- function(expr, gset.idx.list, sample.idxs, rnaseq=FALSE,
                               abs.ranking, parallel.sz=1L, 
                               mx.diff=TRUE, tau=1, kernel=TRUE,
                               verbose=TRUE, BPPARAM=SerialParam(progressbar=verbose)) {
	num_genes <- nrow(expr)
	if (verbose) {
    if (kernel) {
      if (rnaseq)
        cat("Estimating ECDFs with Poisson kernels\n")
      else
        cat("Estimating ECDFs with Gaussian kernels\n")
    } else
      cat("Estimating ECDFs directly\n")
  }

  ## open parallelism only if ECDFs have to be estimated for
  ## more than 100 genes on more than 100 samples
  if (parallel.sz > 1 && length(sample.idxs > 100) && nrow(expr) > 100) {
    if (verbose)
      cat(sprintf("Estimating ECDFs in parallel\n", parallel.sz))
    iter <- function(Y, n_chunks=BiocParallel::multicoreWorkers()) {
      idx <- splitIndices(nrow(Y), min(nrow(Y), n_chunks))
      i <- 0L
      function() {
        if (i == length(idx))
          return(NULL)
        i <<- i + 1L
        Y[idx[[i]], , drop=FALSE]
      }
    }
    gene.density <- bpiterate(iter(expr, 100),
                              compute.gene.density,
                              sample.idxs=sample.idxs,
                              rnaseq=rnaseq, kernel=kernel,
                              REDUCE=rbind, reduce.in.order=TRUE,
                              BPPARAM=BPPARAM)
  } else 
	  gene.density <- compute.gene.density(expr, sample.idxs, rnaseq, kernel)
	
	compute_rank_score <- function(sort_idx_vec){
		tmp <- rep(0, num_genes)
		tmp[sort_idx_vec] <- abs(seq(from=num_genes,to=1) - num_genes/2)
		return (tmp)
	}
	
	rank.scores <- rep(0, num_genes)
  sort.sgn.idxs <- apply(gene.density, 2, order, decreasing=TRUE) # n.genes * n.samples
	
	rank.scores <- apply(sort.sgn.idxs, 2, compute_rank_score)

  m <- bplapply(gset.idx.list, ks_test_m,
                gene.density=rank.scores,
                sort.idxs=sort.sgn.idxs,
                mx.diff=mx.diff, abs.ranking=abs.ranking,
                tau=tau, verbose=verbose,
                BPPARAM=BPPARAM)
  m <- do.call("rbind", m)
  colnames(m) <- colnames(expr)

	return (m)
}


ks_test_m <- function(gset_idxs, gene.density, sort.idxs, mx.diff=TRUE,
                      abs.ranking=FALSE, tau=1, verbose=TRUE){
	
	n.genes <- nrow(gene.density)
	n.samples <- ncol(gene.density)
	n.geneset <- length(gset_idxs)

	geneset.sample.es = .C("ks_matrix_R",
			as.double(gene.density),
			R = double(n.samples),
			as.integer(sort.idxs),
			n.genes,
			as.integer(gset_idxs),
			n.geneset,
			as.double(tau),
			n.samples,
			as.integer(mx.diff),
      as.integer(abs.ranking))$R

	return(geneset.sample.es)
}


## ks-test in R code - testing only
ks_test_Rcode <- function(gene.density, gset_idxs, tau=1, make.plot=FALSE){
	
	n.genes = length(gene.density)
	n.gset = length(gset_idxs)
	
	sum.gset <- sum(abs(gene.density[gset_idxs])^tau)
	
	dec = 1 / (n.genes - n.gset)
	
	sort.idxs <- order(gene.density,decreasing=T)
	offsets <- sort(match(gset_idxs, sort.idxs))
	
	last.idx = 0
	values <- rep(NaN, length(gset_idxs))
	current = 0
	for(i in seq_along(offsets)){
		current = current + abs(gene.density[sort.idxs[offsets[i]]])^tau / sum.gset - dec * (offsets[i]-last.idx-1)
		
		values[i] = current
		last.idx = offsets[i]
	}
	check_zero = current - dec * (n.genes-last.idx)
	#if(check_zero > 10^-15){ 
	#	stop(paste=c("Expected zero sum for ks:", check_zero))
	#}
	if(make.plot){ plot(offsets, values,type="l") } 
	
	max.idx = order(abs(values),decreasing=T)[1]
	mx.value <- values[max.idx]
	
	return (mx.value)
}

rndWalk <- function(gSetIdx, geneRanking, j, R, alpha) {
  indicatorFunInsideGeneSet <- match(geneRanking, gSetIdx)
  indicatorFunInsideGeneSet[!is.na(indicatorFunInsideGeneSet)] <- 1
  indicatorFunInsideGeneSet[is.na(indicatorFunInsideGeneSet)] <- 0
  stepCDFinGeneSet <- cumsum((abs(R[geneRanking, j])^alpha * 
                      indicatorFunInsideGeneSet)) /
                      sum((abs(R[geneRanking, j])^alpha *
                      indicatorFunInsideGeneSet))
  stepCDFoutGeneSet <- cumsum(!indicatorFunInsideGeneSet) /
                       sum(!indicatorFunInsideGeneSet)
  walkStat <- stepCDFinGeneSet - stepCDFoutGeneSet

  sum(walkStat) 
}

setCores <- function(nCores, parallel.sz) {
  if(is.na(nCores)) {
    if (parallel.sz > 0) {
      options(mc.cores=parallel.sz)
    } else {
      options(mc.cores=1)
    }
  } else {
    if (parallel.sz > 0 && parallel.sz < nCores) {
      options(mc.cores=parallel.sz)
    } else {
      options(mc.cores=nCores)
    }
  }
}

ssgsea <- function(X, geneSets, alpha=0.25, parallel.sz,
                   normalization=TRUE, verbose=TRUE,
                   BPPARAM=SerialParam(progressbar=verbose)) {

  p <- nrow(X)
  n <- ncol(X)

  R <- apply(X, 2, function(x,p) as.integer(rank(x)), p)

  es <- matrix(NA, nrow=length(geneSets), ncol=ncol(X))

  ## if there are more gene sets than samples, then
  ## parallelization is done throughout gene sets
  if (length(geneSets) > n) {
    if (verbose) {
      assign("progressBar", txtProgressBar(style=3), envir=globalenv())
      assign("nSamples", n, envir=globalenv())
      assign("iSample", 0, envir=globalenv())
    }

    es <- sapply(1:n, function(j, R, geneSets, alpha) {
                   if (verbose) {
                     assign("iSample", get("iSample", envir=globalenv()) + 1, envir=globalenv())
                     setTxtProgressBar(get("progressBar", envir=globalenv()),
                                       get("iSample", envir=globalenv()) / get("nSamples",
                                                                               envir=globalenv()))
                   }
                   geneRanking <- order(R[, j], decreasing=TRUE)
                   bpprogressbar(BPPARAM) <- FALSE ## since progress is reported by sample
                   es_sample <- bplapply(geneSets, rndWalk, geneRanking, j, R, alpha,
                                         BPPARAM=BPPARAM)

                   unlist(es_sample)
                 }, R, geneSets, alpha)

  } else { ## otherwise, parallelization is done throughout samples

    es <- bplapply(as.list(1:n), function(j, R, geneSets, alpha) {
                     geneRanking <- order(R[, j], decreasing=TRUE)
                     es_sample <- lapply(geneSets, rndWalk, geneRanking, j, R, alpha)

                     unlist(es_sample)
                   }, R, geneSets, alpha, BPPARAM=BPPARAM)
    es <- do.call("cbind", es)
  }

  if (length(geneSets) == 1)
    es <- matrix(es, nrow=1)

  if (normalization) {
    ## normalize enrichment scores by using the entire data set, as indicated
    ## by Barbie et al., 2009, online methods, pg. 2
    es <- apply(es, 2, function(x, es) x / (range(es)[2] - range(es)[1]), es)
  }

  if (length(geneSets) == 1)
    es <- matrix(es, nrow=1)

  rownames(es) <- names(geneSets)
  colnames(es) <- colnames(X)

  if (verbose && length(geneSets) > n) {
    setTxtProgressBar(get("progressBar", envir=globalenv()), 1)
    close(get("progressBar", envir=globalenv()))
  }

  es
}

combinez <- function(gSetIdx, j, Z) sum(Z[gSetIdx, j]) / sqrt(length(gSetIdx))

zscore <- function(X, geneSets, parallel.sz, verbose=TRUE,
                   BPPARAM=SerialParam(progressbar=verbose)) {

  p <- nrow(X)
  n <- ncol(X)

  Z <- t(scale(t(X)))

  es <- matrix(NA, nrow=length(geneSets), ncol=ncol(X))

  ## if there are more gene sets than samples, then
  ## parallelization is done throughout gene sets
  if (length(geneSets) > n) {
    if (verbose) {
      assign("progressBar", txtProgressBar(style=3), envir=globalenv())
      assign("nSamples", n, envir=globalenv())
      assign("iSample", 0, envir=globalenv())
    }

    es <- sapply(1:n, function(j, Z, geneSets) {
                   if (verbose) {
                     assign("iSample", get("iSample", envir=globalenv()) + 1, envir=globalenv())
                     setTxtProgressBar(get("progressBar", envir=globalenv()),
                                       get("iSample", envir=globalenv()) / get("nSamples",
                                                                               envir=globalenv())) }

                     bpprogressbar(BPPARAM) <- FALSE ## since progress is reported by sample
                     es_sample <- bplapply(geneSets, combinez, j, Z,
                                           BPPARAM=BPPARAM)

                     unlist(es_sample)
                   }, Z, geneSets)

  } else { ## otherwise, parallelization is done throughout samples

    es <- bplapply(as.list(1:n), function(j, Z, geneSets) {
                     es_sample <- lapply(geneSets, combinez, j, Z)

                     unlist(es_sample)
                   }, Z, geneSets, BPPARAM=BPPARAM)
    es <- do.call("cbind", es)
  }


  if (length(geneSets) == 1)
    es <- matrix(es, nrow=1)

  rownames(es) <- names(geneSets)
  colnames(es) <- colnames(X)

  if (verbose && length(geneSets) > n) {
    setTxtProgressBar(get("progressBar", envir=globalenv()), 1)
    close(get("progressBar", envir=globalenv()))
  }

  es
}

rightsingularsvdvectorgset <- function(gSetIdx, Z) {
    s <- svd(Z[gSetIdx, ])
  s$v[, 1]
}

plage <- function(X, geneSets, parallel.sz, verbose=TRUE,
                  BPPARAM=SerialParam(progressbar=verbose)) {

  p <- nrow(X)
  n <- ncol(X)

  Z <- t(scale(t(X)))

  es <- bplapply(geneSets, rightsingularsvdvectorgset, Z,
                 BPPARAM=BPPARAM)

  es <- do.call(rbind, es)

  if (length(geneSets) == 1)
    es <- matrix(es, nrow=1)

  rownames(es) <- names(geneSets)
  colnames(es) <- colnames(X)

  es
}

setGeneric("filterGeneSets", function(gSets, ...) standardGeneric("filterGeneSets"))

setMethod("filterGeneSets", signature(gSets="list"),
          function(gSets, min.sz=1, max.sz=Inf) {
	gSetsLen <- sapply(gSets,length)
	return (gSets[gSetsLen >= min.sz & gSetsLen <= max.sz])	
})

setMethod("filterGeneSets", signature(gSets="GeneSetCollection"),
          function(gSets, min.sz=1, max.sz=Inf) {
	gSetsLen <- sapply(geneIds(gSets),length)
	return (gSets[gSetsLen >= min.sz & gSetsLen <= max.sz])	
})



setGeneric("computeGeneSetsOverlap", function(gSets, uniqGenes=unique(unlist(gSets, use.names=FALSE)), ...) standardGeneric("computeGeneSetsOverlap"))

setMethod("computeGeneSetsOverlap", signature(gSets="list", uniqGenes="character"),
          function(gSets, uniqGenes, min.sz=1, max.sz=Inf) {
  totalGenes <- length(uniqGenes)

  ## map to the features requested
  gSets <- lapply(gSets, function(x, y) as.vector(na.omit(match(x, y))), uniqGenes)

  lenGsets <- sapply(gSets, length)
  totalGsets <- length(gSets)

  gSetsMembershipMatrix <- matrix(0, nrow=totalGenes, ncol=totalGsets,
                                  dimnames=list(uniqGenes, names(gSets)))
  members <- cbind(unlist(gSets, use.names=FALSE), rep(1:totalGsets, times=lenGsets))
  gSetsMembershipMatrix[members] <- 1

  .computeGeneSetsOverlap(gSetsMembershipMatrix, min.sz, max.sz)
})

setMethod("computeGeneSetsOverlap", signature(gSets="list", uniqGenes="ExpressionSet"),
          function(gSets, uniqGenes, min.sz=1, max.sz=Inf) {
  uniqGenes <- featureNames(uniqGenes)
  totalGenes <- length(uniqGenes)

  ## map to the actual features for which expression data is available
  gSets <- lapply(gSets, function(x, y) as.vector(na.omit(match(x, y))), uniqGenes)

  lenGsets <- sapply(gSets, length)
  totalGsets <- length(gSets)

  gSetsMembershipMatrix <- matrix(0, nrow=totalGenes, ncol=totalGsets,
                                  dimnames=list(uniqGenes, names(gSets)))
  members <- cbind(unlist(gSets, use.names=FALSE), rep(1:totalGsets, times=lenGsets))
  gSetsMembershipMatrix[members] <- 1

  .computeGeneSetsOverlap(gSetsMembershipMatrix, min.sz, max.sz)
})

setMethod("computeGeneSetsOverlap", signature(gSets="GeneSetCollection", uniqGenes="character"),
          function(gSets, uniqGenes, min.sz=1, max.sz=Inf) {

  gSetsMembershipMatrix <- incidence(gSets)
  gSetsMembershipMatrix <- t(gSetsMembershipMatrix[, colnames(gSetsMembershipMatrix) %in% uniqGenes])

  .computeGeneSetsOverlap(gSetsMembershipMatrix, min.sz, max.sz)
})

setMethod("computeGeneSetsOverlap", signature(gSets="GeneSetCollection", uniqGenes="ExpressionSet"),
          function(gSets, uniqGenes, min.sz=1, max.sz=Inf) {
  ## map gene identifiers of the gene sets to the features in the chip
  ## Biobase::annotation() is necessary to disambiguate from the
  ## 'annotation' argument
  gSets <- mapIdentifiers(gSets, AnnoOrEntrezIdentifier(Biobase::annotation(uniqGenes)))
  
  uniqGenes <- featureNames(uniqGenes)

  gSetsMembershipMatrix <- incidence(gSets)
  gSetsMembershipMatrix <- t(gSetsMembershipMatrix[, colnames(gSetsMembershipMatrix) %in% uniqGenes])

  .computeGeneSetsOverlap(gSetsMembershipMatrix, min.sz, max.sz)
})

.computeGeneSetsOverlap <- function(gSetsMembershipMatrix, min.sz=1, max.sz=Inf) {
  ## gSetsMembershipMatrix should be a (genes x gene-sets) incidence matrix

  lenGsets <- colSums(gSetsMembershipMatrix)

  szFilterMask <- lenGsets >= max(1, min.sz) & lenGsets <= max.sz
  if (!any(szFilterMask))
    stop("No gene set meets the minimum and maximum size filter\n")

  gSetsMembershipMatrix <- gSetsMembershipMatrix[, szFilterMask]
  lenGsets <- lenGsets[szFilterMask]

  totalGsets <- ncol(gSetsMembershipMatrix)

  M <- t(gSetsMembershipMatrix) %*% gSetsMembershipMatrix

  M1 <- matrix(lenGsets, nrow=totalGsets, ncol=totalGsets,
               dimnames=list(colnames(gSetsMembershipMatrix), colnames(gSetsMembershipMatrix)))
  M2 <- t(M1)
  M.min <- matrix(0, nrow=totalGsets, ncol=totalGsets)
  M.min[M1 < M2] <- M1[M1 < M2]
  M.min[M2 <= M1] <- M2[M2 <= M1]
  overlapMatrix <- M / M.min

  return (overlapMatrix)
}

## from https://stat.ethz.ch/pipermail/r-help/2005-September/078974.html
## function: isPackageLoaded
## purpose: to check whether the package specified by the name given in
##          the input argument is loaded. this function is borrowed from
##          the discussion on the R-help list found in this url:
##          https://stat.ethz.ch/pipermail/r-help/2005-September/078974.html
## parameters: name - package name
## return: TRUE if the package is loaded, FALSE otherwise

.isPackageLoaded <- function(name) {
  ## Purpose: is package 'name' loaded?
  ## --------------------------------------------------
  (paste("package:", name, sep="") %in% search()) ||
  (name %in% loadedNamespaces())
}

##
## ARE THESE FUNCTIONS STILL NECESSARY ?????
##

##a <- replicate(1000, compute.null.enrichment(10000,50,make.plot=F))

compute.null.enrichment <- function(n.genes, n.geneset, make.plot=FALSE){
	ranks <- (n.genes/2) - rev(1:n.genes)
	#null.gset.idxs <- seq(1, n.genes, by=round(n.genes / n.geneset))
	null.gset.idxs <- sample(n.genes, n.geneset)
	null.es <- ks_test_Rcode(ranks, null.gset.idxs,make.plot=make.plot)
	return (null.es)
}


load.gmt.data <- function(gmt.file.path){
	tmp <- readLines(gmt.file.path)
	gsets <- list()
	for(i in 1:length(tmp)){
		t <- strsplit(tmp[i],'\t')[[1]]
		gsets[[t[1]]] <- t[3:length(t)]
	}
	return (gsets)
}

compute.gset.overlap.score <- function(gset.idxs){
	n <- length(gset.idxs)
	mx.idx <- max(unlist(gset.idxs, use.names=F))
	l <- c(sapply(gset.idxs, length))
	
	gset.M <- matrix(0, nrow=mx.idx, ncol=n)
	for(i in 1:n){
		gset.M[gset.idxs[[i]],i] = 1
	}
	M <- t(gset.M) %*% gset.M
	
	M1 <- matrix(l, nrow=n, ncol=n)
	M2 <- t(M1)
	M.min <- matrix(0, nrow=n, ncol=n)
	M.min[M1 < M2] <- M1[M1 < M2]
	M.min[M2 <= M1] <- M2[M2 <= M1]
	M.score <- M / M.min
	return (M.score)
}
