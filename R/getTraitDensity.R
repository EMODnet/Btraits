
## ====================================================================
## ====================================================================
## Merging species density and trait data 
## ====================================================================
## ====================================================================


get_trait_density <- function(data,         # density data
                      descriptor, 
                      taxon, 
                      value, 
                      averageOver, 
                      
                      wide=NULL,         # density data, WIDE format (descriptor x taxon) 
                      descriptor_column=1,        # nr/name of column with descriptor names in wide
                      trait,             # species x trait data, WIDE format    
                      taxon_column=1,        # nr/name of column with taxon names in trait
                      trait_class=NULL,  # indices to trait levels - vector
                      trait_score=NULL,  # indices to trait values - vector
                      taxonomy=NULL,     # if !NULL, trait is expanded at higher levels
                      scalewithvalue=TRUE,  # rescale with value - 
                      verbose=FALSE)  

{ 

  if (! missing(data)){
    if (! missing(descriptor))
      descriptor  <- eval(substitute(data.frame(descriptor)), 
                          envir = data, enclos = parent.frame())
    if (! missing(taxon))
      taxon       <- eval(substitute(data.frame(taxon)), 
                          envir = data, enclos = parent.frame())
    if (! missing(value))
      value       <- eval(substitute(data.frame(value)), 
                          envir = data, enclos = parent.frame())
    if (! missing(averageOver))
      averageOver <- eval(substitute(data.frame(averageOver)), 
                          envir = data, enclos = parent.frame())
    data_name <- substitute(data)
  } else data_name <- NA
  
  if (missing(averageOver))
    averageOver <- NULL

  # cast the density data in wide format, if not provided  
  if (is.null(wide)) {
    wide <- long2wide(row         = descriptor, 
                      column      = taxon, 
                      value       = value, 
                      averageOver = averageOver)
    descriptor_column <- attributes(wide)$descriptor_column
  }
  Att         <- attributes(wide)
  
  taxon_names <- attributes(wide)$taxon_names
  if (is.null(taxon_names))taxon_names <- colnames(wide)[-1]
  
  # KARLINE: CHECK IF THISIS WANTED...
#  if (! is.null(taxonomy)) {
#    taxonomy <- taxonomy[taxonomy[,1] %in% taxon_names,]
#    if (! nrow(taxonomy)) stop ("density data and taxonomy have nothing in common")
#  }
  x  <- clearRows(wide, descriptor_column, "wide") # remove descriptor columns
  
  DESCs <- wide[,descriptor_column]
  cn    <- attributes(x)$cn  # name(s) of the descriptor columns  
  if (is.null(taxon_names)) taxon_names <- colnames(x)

# check input of trait data
  trait <- clearRows(trait, taxon_column, "trait") # remove descriptor columns
  row.names.trait <- row.names(trait)
  
  # trait information for the taxa in the data
  trait <- get_trait (taxon    = taxon_names, 
                      trait    = data.frame(taxon=row.names.trait, trait), 
                      taxonomy = taxonomy)
  
  if (any (iun <- which(is.na(trait[,2]))))
    notrait <- trait$taxon[iun]  # species not in trait database
  else 
    notrait <- NA
  
  if (verbose & length(iun)) 
    warning( length(iun), " species are not in the trait database - check attributes()$notrait to find them")
    
  row.names.trait <- trait[,1]
  tnames <- colnames(trait)[-1]
  trait  <- trait[,-1]
  if (is.vector(trait)) {
    trait <- matrix(trait, ncol=1)
    colnames(trait) <- tnames
  }  
  if (nrow(trait) != ncol(x)) {
    stop("dimensions of 'wide' (", nrow(x), ",", ncol(x), ") and 'trait' (", 
        nrow(trait), ",", ncol(trait), ") not compatible- check input or rownames?")
  }
  if (! is.null (row.names.trait) & ! is.null(taxon_names))
    if (!identical(row.names.trait,  taxon_names)) 
      stop("names of 'wide' and 'trait' not compatible")

  NSP             <- as.matrix(trait)
  NSP[is.na(NSP)] <- 0
  X               <- as.matrix(x)
  X[is.na(X)]     <- 0
  
  if (any(!is.numeric(NSP)))
    stop("trait matrix should be numeric - convert categorical variables to fuzzy format")
  cwm <- as.matrix(X) %*% NSP   # density of all traits
  cwm <- data.frame(DESCs, cwm)
  colnames(cwm)[1:length(cn)] <- cn
  
  if (!is.null(trait_class))
    cwm <- fuzzy2crisp(cwm,       # species-trait matrix - in WIDE format
                       taxon_column  = descriptor_column, 
                       trait_class = trait_class,
                       trait_score = trait_score, # indices to trait values - vector
                       standardize = FALSE)
  if (scalewithvalue) {  
    if (length(iun)) X[, iun] <- 0
    
    if (is.vector(cwm[, -descriptor_column]))
      cwm[, -descriptor_column] <- cwm[,-descriptor_column]/rowSums(X)  # descriptor_column/taxon?
    else 
      cwm[, -descriptor_column]  <- sweep(cwm[,-descriptor_column], 
                                 MARGIN = 1, 
                                 STATS  = rowSums(X, na.rm=TRUE),
                                 FUN    = "/")  # descriptor_column/taxon?
  }
  
  row.names(cwm) <- NULL
  cwm <- as.data.frame(cwm)
  attributes(cwm)$names_descriptor  <- Att$names_row
  attributes(cwm)$names_taxon       <- Att$names_column
  attributes(cwm)$names_value       <- Att$names_value
  attributes(cwm)$names_averageOver <- Att$names_averageOver
  attributes(cwm)$subset            <- NA
  
  attributes(cwm)$notrait <- notrait
  cwm
}  
