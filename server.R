source("/srv/shiny-server/global.R")

shinyServer(function(input, output, session) {
	readData = reactive({
		gSep = toBoolean(input$uploadGuessSep)
		gAnno = toBoolean(input$uploadGuessAnno)
		
		if(input$uploadDataInput == 1){
			f = str_c(path, "datasets/", input$uploadSampleData)
		} else if(input$uploadDataInput == 2){
			inFile = input$uploadFile
			if (is.null(input$uploadFile))  {return(NULL)}
			f = inFile$datapath
		} else if(input$uploadDataInput == 3){
			if(is.null(input$uploadCopyPaste) || input$uploadCopyPaste == "") return(NULL)
			f = textConnection(input$uploadCopyPaste)
		} else if(input$uploadDataInput %in% c(4, 6)){
			fname = str_c("settings_", input$uploadSettingsId, ".RData")
			settingsSmall = (input$uploadDataInput == 4)
			settingsLarge = (input$uploadDataInput == 6)
			if(settingsSmall || settingsLarge){
				if(settingsSmall){
					sessPathUsed = sessPath
				} else {
					sessPathUsed = sessPathLarge
				}
				if(!(fname %in% list.files(sessPathUsed))) return(NULL)
				load(file = str_c(sessPathUsed, fname))
				attach(data) #used in return as well: anno, mat, ...
				inputLoaded = inputSaved
				updatePcsAnnos(session, anno, mat, inputLoaded)
				
				#hardcoded manually - found no better way ...
				updates = list(
					updateSelectInput = c("procMethodAgg", "procScaling", "procMethod", 
						"pcaPcx", "pcaPcy", "pcaColor", "pcaShape", "pcaEllipseLineType", "pcaLegendPosition", 
						"hmClustDistRows", "hmClustDistCols", "hmClustMethodRows", "hmClustMethodCols", 
						"hmTreeOrderingRows", "hmTreeOrderingCols", "hmColorScheme", "hmCellBorder"),
					updateCheckboxGroupInput = c("procAnno", "procCentering", "pcaSwitchDir", 
                                       "pcaAnnoColor", "pcaAnnoShape", 
						"pcaShowSampleIds", "pcaShowEllipses", "hmAnno", "hmRevScheme", "hmShowNumbers", 
						"hmShowRownames", "hmShowColnames", "hmShowAnnoTitles", 
            "pcaChangeDataOptions", "pcaChangeDisplayOptions", "pcaChangeColorOptions",
            "pcaChangeShapeOptions", "pcaChangeLabelOptions", "hmChangeClusteringOptions",
            "hmChangeDisplayOptions", "hmChangeLabelOptions"),
					updateRadioButtons = c(),
					updateTabsetPanel = c(),
					
					updateCheckboxInput = c(),
					updateNumericInput = c("pcaPlotRatio", "hmPlotRatio", "pcaEllipseConf", 
            "hmColorRangeMax", "hmColorRangeMin"),
					updateSliderInput = c("pcaPointSize", "pcaPlotWidth", "pcaFontSize", "pcaEllipseLineWidth", 
						"hmFontSizeNumbers", "hmPrecisionNumbers", "hmFontSizeRownames", "hmFontSizeColnames", 
            "hmPlotWidth"), 
					updateTextInput = c("pcaAxisLabelPrefix"),
					updateDateInput = c(),
					
					updateDateRangeInput = c()
				)
				lens = sapply(updates, length)
				updates2 = data.frame(fun = rep(names(updates), lens), id = unlist(updates))
				
				for(i in 1:nrow(updates2)){
					fun = updates2$fun[i]
					id = updates2$id[i]
					val = inputLoaded[[id]]
					
					if(id %in% names(inputLoaded)){
						if(fun == "updateCheckboxGroupInput" & is.null(val)) val = ""
						if(fun %in% c("updateSelectInput", "updateCheckboxGroupInput", "updateRadioButtons", "updateTabsetPanel")){
							get(fun)(session, id, selected = val)
						} else if(fun %in% c("updateCheckboxInput", "updateNumericInput", "updateSliderInput", "updateTextInput", "updateDateInput")){
							get(fun)(session, id, value = val)
						} else if(fun %in% c("updateDateRangeInput")){
							#not supported currently
						}
					}
				}
				
				if(settingsLarge){
					mat = filterRows(session, anno, mat, input, organism = "hsapiens")
				}
				return(list(anno = anno, mat = mat, n = n, sep = sep, inputSaved = input,
				            annoLevsTab = NULL, message = NULL))
			} else {
				return(NULL)
			}
		} else if(input$uploadDataInput == 5){
			if(input$uploadPbDataset != ""){
				ncFile = str_c(projectBrowserPath, input$uploadPbDataset, ".nc")
				if(!file.exists(ncFile)) return(NULL) #when changing platform, initially old dataset remains active
				nc = open.nc(ncFile)
				n = file.inq.nc(nc)$nvars #variable indices 0 .. n-1
				vars = sapply(1:n, function(x) var.inq.nc(nc, x - 1)$name)
				technical = c("gene", "data", "array", "MetadataOrder", "Organism", 
					"ExperimentDescription", "InvestigationTitle", "DatasetID", "DatasetLink",
					"FileFormat", "DatasetType", "VariableLabel")
				varsPrefix = str_sub(vars, 1, 2) #technical also if beginning with double underscore
				w = which(!(vars %in% technical) & !(varsPrefix == "__") & (str_sub(vars, 1, 1) %in% LETTERS))
				varsAnno = vars[w]
				rn = var.get.nc(nc, "gene")
				cn = var.get.nc(nc, "array")
				mat = t(var.get.nc(nc, "data"))
				rownames(mat) = rn
				colnames(mat) = cn
				if(length(w) > 0){
					anno = data.frame(sapply(w, function(x) var.get.nc(nc, x - 1)))
					rownames(anno) = cn
					colnames(anno) = varsAnno
					annoLevs = sapply(anno, function(x) length(unique(x)))
					annoLevsTab = as.data.frame(lapply(annoLevs, identity))
					w2 = which((annoLevs >= input$uploadMinAnnoLevels) & 
                       (annoLevs <= input$uploadMaxAnnoLevels))
					if(length(w2) > 0){
						anno = anno[, w2, drop = FALSE]
						n = ncol(anno)
					} else {
						anno = NULL
						n = 0
					}
				} else {
					anno = NULL
					annoLevsTab = NULL
					n = 0
				}
				#wOrg = which(vars %in% c("Organism"))[1]; org = unique(var.get.nc(nc, wOrg - 1))[1] #old
				org = input$uploadOrganism
        str = strsplit(org, " ")[[1]]
				org2 = str_c(tolower(str_sub(str[1], 1, 1)), str[2])
				close.nc(nc)
				
				mat = filterRows(session, anno, mat, input, organism = org2)
				return(list(anno = anno, mat = mat, n = n, sep = ",", 
                    inputSaved = input, annoLevsTab = annoLevsTab, message = NULL))
			} else {
				return(NULL)
			}
		}
		
		#guess delimiter:
		sepList = c(",", "\t", ";")
		if(gSep){
			rl = readLines(f, warn = FALSE)
      rl = rl[rl != ""] #last line can be empty
			sepNbrsMin = sapply(sepList, function(x) min(str_count(rl, x))) #minimal number of separators on a line
			sep = sepList[which.max(sepNbrsMin)]
			f2 = textConnection(rl) #create new connection
		} else {
			sep = switch(input$uploadFileSep, '1' = ",", '2' = "\t", '3' = ";")
			f2 = f
		}
		
		readText = function(f, sep){
			read.table(f, sep = sep, header = TRUE, fill = TRUE, colClasses = "character", check.names = FALSE)
		}
		safeRead = failwith(NULL, readText, quiet = TRUE)
		message = NULL
		data = safeRead(f2, sep)
    if(!is.null(data)){
      rn = data[, 1]
      if(any(duplicated(rn))){
        #make row names unique
        rn = make.unique(rn)
        message = str_c(message, "Row names were converted because they were not unique!")
      }
      cn = colnames(data)[-1]
      if(any(duplicated(cn))){
        #make column names unique
        cn = make.unique(cn)
        message = str_c(message, "Column names were converted because they were not unique!", sep = "\n")
      }
      data = data[, -1, drop = FALSE]
      rownames(data) = rn
      colnames(data) = cn
    }
    #message = str_c(message, "abc")
		if(is.null(data) || nrow(data) < 1 || ncol(data) < 1) return(NULL)
		data2 = apply(data, 1:2, function(x) gsub(",", ".", x))
		data2[is.na(data2)] = ""
		
		#guess border between annotations and numeric data:
		if(gAnno || !is.numeric(input$uploadNbrAnnoRows) || input$uploadNbrAnnoRows < 0 || input$uploadNbrAnnoRows >= nrow(data)){
			rowsNumeric = apply(data2, 1, function(x) all.is.numeric(x))
			#http://stackoverflow.com/questions/3476782/how-to-check-if-the-number-is-integer
			rowsInteger = apply(data2[rowsNumeric, , drop = FALSE], 1, 
				function(x) isTRUE(all.equal(as.numeric(x), as.integer(x), check.attributes = FALSE)))
			double = which(rowsNumeric)[!rowsInteger] #non-integers
			wNum = which(!rowsNumeric)
			if(length(double) > 0){ #educated guess based on non-integers
				if(length(wNum) > 0){
					double = double[double > max(wNum)] #remove those that are before any non-numeric row
				}
				n = min(double) - 1
			} else { #educated guess based on all numeric values
				if(length(wNum) > 0){
					n = max(wNum)
				} else {
					n = 0
				}
			}
		} else {
			n = input$uploadNbrAnnoRows
		}
		if(n == 0){
			anno = NULL
		} else {
			anno = as.data.frame(t(data[1:n, , drop = FALSE]))
			anno[is.na(anno)] = "NA" #to make filtering and heatmap annotations work correctly
		}
		if(n == nrow(data)){
			mat = NULL
		} else {
			mat = data2[(n + 1):nrow(data2), , drop = FALSE]
			mat = apply(mat, 1:2, as.numeric)
		}
		updatePcsAnnos(session, anno, mat, input)
		return(list(anno = anno, mat = mat, n = n, sep = sep, inputSaved = input, 
                annoLevsTab = NULL, message = message))
	})

	#filter columns
	filterColumns = reactive({
		data = readData()
    
		#missing values:
		#http://stackoverflow.com/questions/20669150/exclude-row-names-from-r-shiny-rendertable
		if(!is.null(data$mat)){
		  data$naRows = findNAs(data$mat, 1)
		  data$naCols = findNAs(data$mat, 2)
      data$naRowsAll = names(data$naRows[data$naRows == ncol(data$mat)])
      data$naColsAll = names(data$naCols[data$naCols == nrow(data$mat)])
		  wr = which(!(rownames(data$mat) %in% data$naRowsAll))
		  wc = which(!(colnames(data$mat) %in% data$naColsAll))
		  data$mat = data$mat[wr, wc, drop = FALSE]
		  data$anno = data$anno[wc, , drop = FALSE]
		}
    
		if(!is.null(data$anno)){
			w = findRetainedColumns(data$anno, data$inputSaved)
			if(length(w) > 0){
				data$anno = data$anno[w, , drop = FALSE]
				data$mat = data$mat[, w, drop = FALSE]
			} else {
				data$anno = data$mat = NULL
			}
		}
    
    if(toBoolean(data$inputSaved$uploadMatrixTranspose)){
      if(!is.null(data$mat)){
        data$mat = t(data$mat)
      }
      data$anno = NULL
      updatePcsAnnos(session, data$anno, data$mat, data$inputSaved)
    }
    
		data
	})
  
	#http://stackoverflow.com/questions/18816666/shiny-change-data-input-of-buttons
	values = reactiveValues()
	observe({
		values$data = filterColumns()
	})
	
	#initial data
	output$uploadAnnoLevelsTable = renderTable({
		values$data$annoLevsTab
	})

	output$uploadAnnoInfo = renderPrint({
		if(is.null(values$data$anno)){
			ns = c(0, 0)
		} else {
			ns = rev(dim(values$data$anno))
		}
		plurals = ifelse(ns != 1, "s", "")
		p(str_c("Annotations (", ns[1], " row", plurals[1], ", ", ns[2], " column", plurals[2], "):"))
	})
	
	output$uploadAnnoTable = renderTable({
		if(is.null(values$data$anno)) return(NULL)
		cutMatrix(t(values$data$anno))
	})
	
	output$uploadDataInfo = renderPrint({
		if(is.null(values$data$mat)){
			ns = c(0, 0)
		} else {
			ns = dim(values$data$mat)
		}
		plurals = ifelse(ns != 1, "s", "")
		p(str_c("Numeric data (", ns[1], " row", plurals[1], ", ", ns[2], " column", plurals[2], "):"))
	})
	
	output$uploadDataTable = renderTable({
		cutMatrix(values$data$mat)
	})
  
	output$uploadNAsRows = renderTable({
	  if(!is.null(values$data$mat)){
      gp = values$data$naRows
	    validate(
	      need(!is.null(gp), "No NAs in rows.")
	    )
	    return(cutMatrix(rbind(gp), digits = 0))
	  } else {
	    #return(data.frame(All = 0L))
      return(NULL)
	  }
	}, include.rownames = FALSE)
	
	output$uploadNAsCols = renderTable({
	  if(!is.null(values$data$mat)){
	    gp = values$data$naCols
	    validate(
	      need(!is.null(gp), "No NAs in columns.")
      )
	    return(cutMatrix(rbind(gp), digits = 0))
	  } else {
	    #return(data.frame(All = 0L))
      return(NULL)
	  }
	}, include.rownames = FALSE)
	
  output$uploadWarnings = renderText({
    missing = c(input$uploadPbDataset == "", input$uploadPbPathway == "")
    words = c("a dataset", "a pathway (or change row filtering type)")
    warnWords = str_c(words[missing], collapse = " and ")
    validate(
      need(is.null(values$data$message), values$data$message),
      need(!(input$uploadDataInput == 2 & is.null(input$uploadFile)), "Please choose a file to upload!"),
      need(!(input$uploadDataInput == 3 & (is.null(input$uploadCopyPaste) || input$uploadCopyPaste == "")), "Please copy your data to the text box on the left!"),
      need(!(input$uploadDataInput == 5 & input$uploadRowFiltering == 1 & 
          (input$uploadPbDataset == "" | input$uploadPbPathway == "")), 
          str_c("Please choose ", warnWords, "!")),
      need(!(input$uploadDataInput == 5 & input$uploadRowFiltering != 1 & 
          input$uploadPbDataset == ""), "Please choose a dataset!"),
      need(!(input$uploadDataInput %in% c(4, 6) & 
               input$uploadSettingsId == ""), "No settings ID found!")
    )
    validate(
      need(!is.null(values$data$mat), "No numeric data found, you can visit 'Help' tab for instructions about data format!")
    )
    if(!is.null(values$data$mat)){
      nar = values$data$naRowsAll
      nac = values$data$naColsAll
      sd0r = findSD0(values$data$mat, 1)
      sd0c = findSD0(values$data$mat, 2)
      validate(
        need(length(nar) == 0, str_c("The following rows had all missing values and were removed: ", str_c(nar, collapse = ", "))),
        need(length(nac) == 0, str_c("The following columns had all missing values and were removed: ", str_c(nac, collapse = ", "))),
        need(length(sd0r) == 0, str_c("The following rows are constant and may cause problems with some clustering distances (e.g. correlation): ", str_c(sd0r, collapse = ", "))),
        need(length(sd0c) == 0, str_c("The following columns are constant and may cause problems with some clustering distances (e.g. correlation): ", str_c(sd0c, collapse = ", ")))
      )
    } else {
      return(NULL)
    }
  })
	
	#pre-processing
	getProc = reactive({
	  proc = dataProcess(data = values$data)
    updateNbrs(session, proc$matImputed)
    proc
	})
	
	output$procPcaVarInfo = renderPrint({
		vt = getProc()$varTable
		if(is.null(vt)){
			ns = 0
		} else {
			ns = ncol(vt)
		}
		plurals = ifelse(ns != 1, "s", "")
		p(str_c("Variance explained (", ns, " component", plurals, "):"))
	})
	
	output$procPcaVarTable = renderTable({
		cutMatrix(getProc()$varTable)
	})
	
	output$procMatPcaInfo = renderPrint({
		mp = getProc()$matPca
		if(is.null(mp)){
			ns = c(0, 0)
		} else {
			ns = dim(mp)
		}
		plurals = ifelse(ns != 1, "s", "")
		p(str_c("Principal components (", ns[1], " data point", plurals[1], " in rows, ", ns[2], " component", plurals[2], " in columns):"))
	})
	
	output$procMatPca = renderTable({
		cutMatrix(getProc()$matPca)
	})

	output$procPcaLoadingsInfo = renderPrint({
	  ld = getProc()$pcaLoadings
	  if(is.null(ld)){
	    ns = c(0, 0)
	  } else {
	    ns = dim(ld)
	  }
	  plurals = ifelse(ns != 1, "s", "")
	  p(str_c("Component loadings (", ns[1], " dimension", plurals[1], " in rows, ", ns[2], " component", plurals[2], " in columns):"))
	})
  
	output$procPcaLoadings = renderTable({
	  cutMatrix(getProc()$pcaLoadings)
	})
  
	#PCA
	getPCA = reactive({
		data = getProc()
		#http://shiny.rstudio.com/articles/validation.html
		validate(
			need(!is.null(data), "No data found, please revisit 'Data upload' tab!")
		)
		plotPCA(data)
	})
	
	output$pca = renderPlot({
		print(getPCA()[[1]])
	}, height = function() getPCA()[[2]], width = function() getPCA()[[3]])
	
	
	#heatmap
	getClust = reactive({
		data = getProc()
		validate(
			need(!is.null(data), "No data found, please revisit 'Data upload' tab!"),
			need(nrow(data$mat) <= maxDimensionHeatmap, str_c("Data matrices with more than ", maxDimensionHeatmap, 
        " rows are currently not supported, please revisit 'Data upload' tab and change row filtering options or upload a smaller file!")),
			need(ncol(data$mat) <= maxDimensionHeatmap, str_c("Data matrices with more than ", maxDimensionHeatmap, 
        " columns are currently not supported, please revisit 'Data upload' tab and filter some columns or collapse columns with similar annotations on 'Data pre-processing' tab or upload a smaller file!"))
		)
		data$hcRows = calcClustering(data$matImputed, data$inputSaved$hmClustDistRows, 
      data$inputSaved$hmClustMethodRows, data$inputSaved$hmTreeOrderingRows)
		data$hcCols = calcClustering(t(data$matImputed), data$inputSaved$hmClustDistCols, 
      data$inputSaved$hmClustMethodCols, data$inputSaved$hmTreeOrderingCols)
		data
	})
	
	getHeatmap = reactive({
		data = getClust()
		plotHeatmap(data)
	})
	
	#http://shiny.rstudio.com/articles/images.html
	output$heatmap = renderImage({
		outfile = tempfile(fileext = '.png', tmpdir = sessPath)
		gh = plotHeatmap(data = getClust(), filename = outfile)
    list(src = outfile, contentType = 'image/png', width = gh$picw, height = gh$pich)
	}, deleteFile = TRUE)
	
	#export
	output$exportSaveSettingsText = renderPrint({
		data = values$data
		#https://gist.github.com/wch/9606002
		clicked = input$exportSaveSettingsButton #takes dependency since outside isolate()
		isolate({
			sessId = convert2safe(input$exportSaveDeleteSettingsId)
			if (clicked){
				lf = list.files(sessPath)
				fname = str_c("settings_", sessId, ".RData")
				if(fname %in% lf){
					text = p(str_c("Settings ID '", sessId, "' is already in use, please choose another ID!"), 
						style = "color:red;")
				} else {
					data$inputSaved = isolate(reactiveValuesToList(data$inputSaved)) #convert to list to save space
					data$inputSaved$uploadFile = data$inputSaved$uploadCopyPaste = NULL #remove to save space
					save(data, file = str_c(sessPath, fname))
					sess = session$clientData
					if(sess$url_port == ""){
						port = ""
					} else {
						port = str_c(":", sess$url_port)
					}
					if(sess$url_search %in% c("", "?")){
						getpar = "?"
					} else {
						getpar = str_c(sess$url_search, "&")
					}
					link = str_c(sess$url_protocol, "//", sess$url_hostname, port, 
						sess$url_pathname, getpar, "s=", sessId)
					text = p("Your settings are now saved and can be re-loaded by visiting ", 
						a(link, href = link, target = "_blank"), style = "color:green;")
				}
			}
		})
		text
	})
	
	output$exportDeleteSettingsText = renderPrint({
		clicked = input$exportDeleteSettingsButton #takes dependency since outside isolate()
		isolate({
			sessId = convert2safe(input$exportSaveDeleteSettingsId)
			if (clicked){
				lf = list.files(sessPath)
				fname = str_c("settings_", sessId, ".RData")
				if(fname %in% lf){
					unlink(str_c(sessPath, fname))
					text = p(str_c("Your settings with ID '", sessId, "' are now deleted!"), style = "color:green;")
				} else {
					text = p(str_c("Settings ID '", sessId, "' was not in use!"), style = "color:red;")
				}
			}
		})
		text
	})
	
	output$exportDownloadInitialData = downloadHandler(
	  filename = function() { str_c(toolname, "InitialData.csv") },
	  content = function(file) {
	    d = rbind(t(values$data$anno), values$data$mat)
	    writeOutput(d, file)
	  }
	)
  
	output$exportDownloadProcessedData = downloadHandler(
	  filename = function() { str_c(toolname, "ProcessedData.csv") },
	  content = function(file) {
      d = getProc()$matImputed
      writeOutput(d, file)
	  }
	)

	output$exportDownloadPCAscores = downloadHandler(
	  filename = function() { str_c(toolname, "PCAscores.csv") },
	  content = function(file) {
	    d = getProc()$matPca
	    writeOutput(d, file)
	  }
	)
  
	output$exportDownloadPCAloadings = downloadHandler(
	  filename = function() { str_c(toolname, "PCAloadings.csv") },
	  content = function(file) {
	    d = getProc()$pcaLoadings
	    writeOutput(d, file)
	  }
	)
  
	output$exportDownloadPCAvartable = downloadHandler(
	  filename = function() { str_c(toolname, "PCAvartable.csv") },
	  content = function(file) {
	    d = getProc()$varTable
	  }
	)
  
	observe({
		set.seed(NULL) #force random start
		sessId = paste(sample(c(letters, LETTERS), 15, replace = TRUE), collapse = "")
		updateTextInput(session, "exportSaveDeleteSettingsId", value = sessId)
	})
	
	observe({
		if (input$uploadClearTextButton == 0) return()
		isolate({ updateTextInput(session, "uploadCopyPaste", label = ",", value = "") })
	})
	
	#update calculated default delimiter and number of annotation rows:
	observe({
		d = values$data
		if(!is.null(d)){
			updateNumericInput(session, "uploadNbrAnnoRows", value = d$n)
			updateRadioButtons(session, "uploadFileSep", selected = switch(d$sep, "," = '1', "\t" = '2', ";" = '3'))
		}
	})
	
	#update settings if there is GET variable:
	observe({
		search = parseQueryString(session$clientData$url_search)
		var = ""
		if("s" %in% names(search) && search$s != ""){
			var = "s"
			sel = "4"
		} else if("p" %in% names(search) && search$p != ""){
			var = "p"
			sel = "6"
		}
		if(var %in% c("s", "p")){
			id = search[[var]]
			updateTabsetPanel(session, "tabs1", selected = "Data upload")
			updateRadioButtons(session, "uploadDataInput", selected = sel)
			updateTextInput(session, "uploadSettingsId", value = id)
		}
	})
	
	output$exportDownloadPdfPCA = output$exportDownloadPdfHeatmap = downloadHandler(
		filename = function() { str_c(toolname, input$tabs1, ".pdf") },
		content = function(file) {
			type = input$tabs1 #PCA or Heatmap
			fun = str_c("get", type)
			if(type == "PCA"){
				pdf(file, width = get(fun)()[[3]] / 72, height = get(fun)()[[2]] / 72)
				print(get(fun)()[[1]])
			} else if(type == "Heatmap"){
				pdf(file, width = input$hmPlotWidth / 2.54, height = input$hmPlotRatio * input$hmPlotWidth / 2.54)
				plotHeatmap(data = getClust())
			}
			dev.off()
		},
		contentType = "application/pdf"
	)
	
	output$exportDownloadEpsPCA = output$exportDownloadEpsHeatmap = downloadHandler(
		filename = function() { str_c(toolname, input$tabs1, ".eps") },
		content = function(file) {
			type = input$tabs1 #PCA or Heatmap
			fun = str_c("get", type)
			if(type == "PCA"){
				postscript(file, horizontal = FALSE, onefile = FALSE, paper = "special", 
					width = get(fun)()[[3]] / 72, height = get(fun)()[[2]] / 72)
				print(get(fun)()[[1]])
			} else if(type == "Heatmap"){
				postscript(file, horizontal = FALSE, onefile = FALSE, paper = "special", 
					width = input$hmPlotWidth / 2.54, height = input$hmPlotRatio * input$hmPlotWidth / 2.54)
				plotHeatmap(data = getClust())
			}
			dev.off()
		},
		contentType = "application/postscript"
	)
	
	output$exportDownloadSvgPCA = output$exportDownloadSvgHeatmap = downloadHandler(
		filename = function() { str_c(toolname, input$tabs1, ".svg") },
		content = function(file) {
			type = input$tabs1 #PCA or Heatmap
			fun = str_c("get", type)
			if(type == "PCA"){
				svg(file, width = get(fun)()[[3]] / 72, height = get(fun)()[[2]] / 72)
				print(get(fun)()[[1]])
			} else if(type == "Heatmap"){
				svg(file, width = input$hmPlotWidth / 2.54, height = input$hmPlotRatio * input$hmPlotWidth / 2.54)
				ph = plotHeatmap(data = getClust())
				ph[[1]]
			}
			dev.off()
		},
		contentType = "image/svg"
	)
    
  #update list of datasets:
	observe({
		if(input$uploadDataInput == 5){
		  org = input$uploadOrganism
		  if(org != ""){
		    str = strsplit(org, " ")
		    org_short = str_c(tolower(str_sub(str[[1]][1], 1, 1)), str[[1]][2])
		    load(file = str_c(pwPath, "clustvisInput_", pwDate, "_spec_", org_short, ".RData"))
		    w = which(uploadDatasetTable$organism == input$uploadOrganism & 
		                uploadDatasetTable$nAnnos >= input$uploadMinAnnoTracks)
		    df = uploadDatasetTable[w, , drop = FALSE]
		    dslist = df$id2
		    names(dslist) = df$label3
		    dslist = c("", dslist)
		    updateSelectizeInput(session, "uploadPbDataset", choices = dslist, selected = "", server = TRUE) #server = TRUE is faster, but doesn't work correctly in the new version of shiny (0.11.1)
		  }
		}
	})
	
	#update list of pathways:
	observe({
		if(input$uploadDataInput %in% 5:6){
      if(input$uploadDataInput == 5){
        org = input$uploadOrganism
      } else {
        org = "Homo sapiens" #default for prepared gene expression datasets
      }
      if(org != ""){
        str = strsplit(org, " ")
        org_short = str_c(tolower(str_sub(str[[1]][1], 1, 1)), str[[1]][2])
        load(file = str_c(pwPath, "clustvisInput_", pwDate, "_spec_", org_short, ".RData"))
        pwlist = c("", uploadPathwayList)
        updateSelectizeInput(session, "uploadPbPathway", choices = pwlist, selected = "", server = TRUE)
      }
		}
	})
	
	#generate filtering options:
	output$uploadColumnFilters = renderUI({
		anno = readData()$anno #use original unfiltered data for defining groups
		if(!is.null(anno)){
			cn = colnames(anno)
			cnCut = cutLong(cn, maxCharactersAnnotations)
			names(cn) = str_c("by '", cnCut, "'")
			taglist = list()
			for(i in 1:length(cn)){
				n = length(taglist)
				id = str_c("uploadColumnFilters", i)
				uni = sort(as.vector(unique(anno[, i])))
				uniCut = cutLong(uni, maxCharactersAnnotations)
				names(uni) = str_c("- ", uniCut)
				taglist[[n + 1]] = checkboxGroupInput(id, NULL, choices = cn[i])
				taglist[[n + 2]] = conditionalPanel(condition = str_c("input.", id, " != ''"),
					checkboxGroupInput(str_c(id, "sub"), NULL, choices = uni, selected = uni)
				)
			}
			taglist
		}
	})
	
	output$legendPCA <- renderUI({
	  data = getProc()
    if(!is.null(data)){
      leg = c()
      if(data$inputSaved$procMethodAgg != "no collapse"){
        leg = append(leg, c("Columns with similar annotations are collapsed by taking ", 
                            data$inputSaved$procMethodAgg, " inside each group. "))
      }
      sc = names(procScalings)[match(data$inputSaved$procScaling, procScalings)]
      meth = names(procMeth)[match(data$inputSaved$procMethod, procMeth)]
      pcs = c(as.numeric(data$inputSaved$pcaPcx), as.numeric(data$inputSaved$pcaPcy))
      leg = append(leg, c(capitalize(sc), " is applied to rows; ", meth, " is used to calculate principal components. X and Y axis show principal component ", data$inputSaved$pcaPcx, 
                          " and principal component ", data$inputSaved$pcaPcy, " that explain ", round(data$varTable[1, pcs[1]] * 100, 1), "% and ", round(data$varTable[1, pcs[2]] * 100, 1), "% of the total variance, respectively. "))
      if(toBoolean(data$inputSaved$pcaShowEllipses)){
        leg = append(leg, c("Prediction ellipses are such that with probability ", 
                            data$inputSaved$pcaEllipseConf, 
                            ", a new observation from the same group will fall inside the ellipse. "))
      }
      leg = append(leg, c("N = ", nrow(data$matPca), " data points."))
      #http://stackoverflow.com/questions/23233497/outputting-multiple-lines-of-text-with-rendertext-in-r-shiny
      return(HTML("<h5>Caption example</h5><p>", str_c(leg, collapse = ""), "</p>"))
    }
	})
  
	output$legendHeatmap <- renderUI({
    if(!is.null(values$data) && all(dim(values$data$mat) <= maxDimensionHeatmap)){
      data = getProc()
      leg = c()
      if(data$inputSaved$procMethodAgg != "no collapse"){
        leg = append(leg, c("Columns with similar annotations are collapsed by taking ", 
                            data$inputSaved$procMethodAgg, " inside each group. "))
      }
      sc = names(procScalings)[match(data$inputSaved$procScaling, procScalings)]
      scaling = str_c(sc, " is applied to rows. ")
      if(toBoolean(data$inputSaved$procCentering)){
        leg = append(leg, c("Rows are centered; ", scaling))
      } else {
        leg = append(leg, capitalize(scaling))
      }
      meth = names(procMeth)[match(data$inputSaved$procMethod, procMeth)]
      if(sum(is.na(data$mat)) > 0){
        leg = append(leg, c(meth, " is used for missing value estimation. "))
      }
      distLabelRows = names(clustDists)[match(data$inputSaved$hmClustDistRows, clustDists)]
      distLabelCols = names(clustDists)[match(data$inputSaved$hmClustDistCols, clustDists)]
      linkLabelRows = names(clustMethods)[match(data$inputSaved$hmClustMethodRows, clustMethods)]
      linkLabelCols = names(clustMethods)[match(data$inputSaved$hmClustMethodCols, clustMethods)]
      if(distLabelRows == distLabelCols & linkLabelRows == linkLabelCols & distLabelRows != noClust){
        leg = append(leg, c("Both rows and columns are clustered using ", distLabelRows, " distance and ", linkLabelRows, " linkage. "))
      } else {
        if(distLabelRows != noClust){
          leg = append(leg, c("Rows are clustered using ", distLabelRows, " distance and ", linkLabelRows, " linkage. "))
        }
        if(distLabelCols != noClust){
          leg = append(leg, c("Columns are clustered using ", distLabelCols, " distance and ", linkLabelCols, " linkage. "))
        }
      }
      return(HTML("<h5>Caption example</h5><p>", str_c(leg, collapse = ""), "</p>"))
    }
	})
  
  #http://shiny.rstudio.com/articles/datatables.html
	output$helpDatasetTable = renderDataTable({
	  helpDatasetTable
	}, options = helpTablesOptions)
  
	output$helpPathwayTable = renderDataTable({
	  helpPathwayTable
	}, options = helpTablesOptions)
})

