rf_plots <- c(
  "None" = "none",
  "Permutation Importance" = "vip",
  "Prediction plots" = "pred_plot",
  "Partial Dependence" = "pdp",
  "Dashboard" = "dashboard"
)

## list of function arguments
rf_args <- as.list(formals(rforest))

## list of function inputs selected by user
rf_inputs <- reactive({
  ## loop needed because reactive values don't allow single bracket indexing
  rf_args$data_filter <- if (input$show_filter) input$data_filter else ""
  rf_args$arr <- if (input$show_filter) input$data_arrange else ""
  rf_args$rows <- if (input$show_filter) input$data_rows else ""
  rf_args$dataset <- input$dataset
  for (i in r_drop(names(rf_args))) {
    rf_args[[i]] <- input[[paste0("rf_", i)]]
  }
  rf_args
})

rf_pred_args <- as.list(if (exists("predict.rforest")) {
  formals(predict.rforest)
} else {
  formals(radiant.model:::predict.rforest)
})

# list of function inputs selected by user
rf_pred_inputs <- reactive({
  # loop needed because reactive values don't allow single bracket indexing
  for (i in names(rf_pred_args)) {
    rf_pred_args[[i]] <- input[[paste0("rf_", i)]]
  }

  rf_pred_args$pred_cmd <- rf_pred_args$pred_data <- ""
  if (input$rf_predict == "cmd") {
    rf_pred_args$pred_cmd <- gsub("\\s{2,}", " ", input$rf_pred_cmd) %>%
      gsub(";\\s+", ";", .) %>%
      gsub("\"", "\'", .)
  } else if (input$rf_predict == "data") {
    rf_pred_args$pred_data <- input$rf_pred_data
  } else if (input$rf_predict == "datacmd") {
    rf_pred_args$pred_cmd <- gsub("\\s{2,}", " ", input$rf_pred_cmd) %>%
      gsub(";\\s+", ";", .) %>%
      gsub("\"", "\'", .)
    rf_pred_args$pred_data <- input$rf_pred_data
  }
  rf_pred_args
})

rf_plot_args <- as.list(if (exists("plot.rforest")) {
  formals(plot.rforest)
} else {
  formals(radiant.model:::plot.rforest)
})

## list of function inputs selected by user
rf_plot_inputs <- reactive({
  ## loop needed because reactive values don't allow single bracket indexing
  for (i in names(rf_plot_args)) {
    rf_plot_args[[i]] <- input[[paste0("rf_", i)]]
  }
  rf_plot_args
})

rf_pred_plot_args <- as.list(if (exists("plot.model.predict")) {
  formals(plot.model.predict)
} else {
  formals(radiant.model:::plot.model.predict)
})

# list of function inputs selected by user
rf_pred_plot_inputs <- reactive({
  # loop needed because reactive values don't allow single bracket indexing
  for (i in names(rf_pred_plot_args)) {
    rf_pred_plot_args[[i]] <- input[[paste0("rf_", i)]]
  }
  rf_pred_plot_args
})

output$ui_rf_rvar <- renderUI({
  req(input$rf_type)

  withProgress(message = "Acquiring variable information", value = 1, {
    if (input$rf_type == "classification") {
      isFct <- .get_class() %in% c("factor")
      # vars <- two_level_vars()
      vars <- varnames()[isFct]
    } else {
      isNum <- .get_class() %in% c("integer", "numeric", "ts")
      vars <- varnames()[isNum]
    }
  })

  init <- if (input$rf_type == "classification") {
    if (is.empty(input$logit_rvar)) isolate(input$rf_rvar) else input$logit_rvar
  } else {
    if (is.empty(input$reg_rvar)) isolate(input$rf_rvar) else input$reg_rvar
  }

  selectInput(
    inputId = "rf_rvar",
    label = "Response variable:",
    choices = vars,
    selected = state_single("rf_rvar", vars, init),
    multiple = FALSE
  )
})

output$ui_rf_lev <- renderUI({
  req(input$rf_type == "classification")
  req(available(input$rf_rvar))
  levs <- .get_data()[[input$rf_rvar]] %>%
    as_factor() %>%
    levels()

  init <- if (is.empty(input$logit_lev)) isolate(input$rf_lev) else input$logit_lev
  selectInput(
    inputId = "rf_lev", label = "Choose first level:",
    choices = levs,
    selected = state_init("rf_lev", init)
  )
})
output$ui_rf_hyperparams <- renderUI({
  tagList(
    h4("Hypertuning Parameters Selection"),
    textInput("cv_rf_mtry", "mtry (comma-separated):", value = "1,2,3"),
    textInput("cv_rf_num_trees", "# trees (comma-separated):", value = "100,200,300"),
    textInput("cv_rf_min_node_size", "Min node size (comma-separated):", value = "1,10"),
    textInput("cv_rf_sample_fraction", "Sample fraction (comma-separated):", value = "0.5,0.75,1"),
    numericInput("cv_rf_seed", "Seed:", value = 1234),
    actionButton("cv_rf_run", "Run Cross-Validation", icon = icon("play", verify_fa = FALSE), class = "btn-success"),
  )
})


output$ui_rf_evar <- renderUI({
  if (not_available(input$rf_rvar)) {
    return()
  }
  vars <- varnames()
  if (length(vars) > 0) {
    vars <- vars[-which(vars == input$rf_rvar)]
  }

  init <- if (input$rf_type == "classification") {
    if (is.empty(input$logit_evar)) isolate(input$rf_evar) else input$logit_evar
  } else {
    if (is.empty(input$reg_evar)) isolate(input$rf_evar) else input$reg_evar
  }

  selectInput(
    inputId = "rf_evar",
    label = "Explanatory variables:",
    choices = vars,
    selected = state_multiple("rf_evar", vars, init),
    multiple = TRUE,
    size = min(10, length(vars)),
    selectize = FALSE
  )
})

# function calls generate UI elements
output_incl("rf")
output_incl_int("rf")

output$ui_rf_wts <- renderUI({
  isNum <- .get_class() %in% c("integer", "numeric", "ts")
  vars <- varnames()[isNum]
  if (length(vars) > 0 && any(vars %in% input$rf_evar)) {
    vars <- base::setdiff(vars, input$rf_evar)
    names(vars) <- varnames() %>%
      {
        .[match(vars, .)]
      } %>%
      names()
  }
  vars <- c("None", vars)

  selectInput(
    inputId = "rf_wts", label = "Weights:", choices = vars,
    selected = state_single("rf_wts", vars),
    multiple = FALSE
  )
})

output$ui_rf_store_pred_name <- renderUI({
  init <- state_init("rf_store_pred_name", "pred_rf")
  textInput(
    "rf_store_pred_name",
    "Store predictions:",
    init
  )
})

# output$ui_rf_store_res_name <- renderUI({
#   req(input$dataset)
#   textInput("rf_store_res_name", "Store residuals:", "", placeholder = "Provide variable name")
# })

## reset prediction and plot settings when the dataset changes
observeEvent(input$dataset, {
  updateSelectInput(session = session, inputId = "rf_predict", selected = "none")
  updateSelectInput(session = session, inputId = "rf_plots", selected = "none")
})

## reset prediction settings when the model type changes
observeEvent(input$rf_type, {
  updateSelectInput(session = session, inputId = "rf_predict", selected = "none")
  updateSelectInput(session = session, inputId = "rf_plots", selected = "none")
})

output$ui_rf_predict_plot <- renderUI({
  req(input$rf_rvar, input$rf_type)
  if (input$rf_type == "classification") {
    var_colors <- ".class" %>% set_names(input$rf_rvar)
    predict_plot_controls("rf", vars_color = var_colors, init_color = ".class")
  } else {
    predict_plot_controls("rf")
  }
})

output$ui_rf_plots <- renderUI({
  req(input$rf_type)
  if (input$rf_type != "regression") {
    rf_plots <- head(rf_plots, -1)
  }
  selectInput(
    "rf_plots", "Plots:",
    choices = rf_plots,
    selected = state_single("rf_plots", rf_plots)
  )
})

output$ui_rf_nrobs <- renderUI({
  nrobs <- nrow(.get_data())
  choices <- c("1,000" = 1000, "5,000" = 5000, "10,000" = 10000, "All" = -1) %>%
    .[. < nrobs]
  selectInput(
    "rf_nrobs", "Number of data points plotted:",
    choices = choices,
    selected = state_single("rf_nrobs", choices, 1000)
  )
})

## add a spinning refresh icon if the model needs to be (re)estimated
run_refresh(rf_args, "rf", tabs = "tabs_rf", label = "Estimate model", relabel = "Re-estimate model")

output$ui_rf <- renderUI({
  req(input$dataset)
  tagList(
    conditionalPanel(
      condition = "input.tabs_rf == 'Model Summary'",
      wellPanel(
        actionButton("rf_run", "Estimate model", width = "100%", icon = icon("play", verify_fa = FALSE), class = "btn-success")
      )
    ),
    wellPanel(
      conditionalPanel(
        condition = "input.tabs_rf == 'Model Summary'",
        radioButtons(
          "rf_type",
          label = NULL, c("classification", "regression"),
          selected = state_init("rf_type", "classification"),
          inline = TRUE
        ),
        uiOutput("ui_rf_rvar"),
        uiOutput("ui_rf_lev"),
        uiOutput("ui_rf_evar"),
        uiOutput("ui_rf_wts"),
        with(tags, table(
          tr(
            td(numericInput(
              "rf_mtry",
              label = "mtry:", min = 1, max = 20,
              value = state_init("rf_mtry", 1)
            ), width = "50%"),
            td(numericInput(
              "rf_num.trees",
              label = "# trees:", min = 1, max = 1000,
              value = state_init("rf_num.trees", 100)
            ), width = "50%")
          ),
          width = "100%"
        )),
        with(tags, table(
          tr(
            td(numericInput(
              "rf_min.node.size",
              label = "Min node size:", min = 1, max = 100,
              step = 1, value = state_init("rf_min.node.size", 1)
            ), width = "50%"),
            td(numericInput(
              "rf_sample.fraction",
              label = "Sample fraction:",
              min = 0, max = 1, step = 0.1,
              value = state_init("rf_sample.fraction", 1)
            ), width = "50%")
          ),
          width = "100%"
        )),
        numericInput("rf_seed", label = "Seed:", value = state_init("rf_seed", 1234)),
        uiOutput("ui_rf_hyperparams")
      ),
      conditionalPanel(
        condition = "input.tabs_rf == 'Predictions'",
        selectInput(
          "rf_predict",
          label = "Prediction input type:", reg_predict,
          selected = state_single("rf_predict", reg_predict, "none")
        ),
        conditionalPanel(
          "input.rf_predict == 'data' | input.rf_predict == 'datacmd'",
          selectizeInput(
            inputId = "rf_pred_data", label = "Prediction data:",
            choices = c("None" = "", r_info[["datasetlist"]]),
            selected = state_single("rf_pred_data", c("None" = "", r_info[["datasetlist"]])),
            multiple = FALSE
          )
        ),
        conditionalPanel(
          "input.rf_predict == 'cmd' | input.rf_predict == 'datacmd'",
          returnTextAreaInput(
            "rf_pred_cmd", "Prediction command:",
            value = state_init("rf_pred_cmd", ""),
            rows = 3,
            placeholder = "Type a formula to set values for model variables (e.g., carat = 1; cut = 'Ideal') and press return"
          )
        ),
        conditionalPanel(
          condition = "input.rf_predict != 'none'",
          checkboxInput("rf_pred_plot", "Plot predictions", state_init("rf_pred_plot", FALSE)),
          conditionalPanel(
            "input.rf_pred_plot == true",
            uiOutput("ui_rf_predict_plot")
          )
        ),
        ## only show if full data is used for prediction
        conditionalPanel(
          "input.rf_predict == 'data' | input.rf_predict == 'datacmd'",
          tags$table(
            tags$td(uiOutput("ui_rf_store_pred_name")),
            tags$td(actionButton("rf_store_pred", "Store", icon = icon("plus", verify_fa = FALSE)), class = "top")
          )
        )
      ),
      conditionalPanel(
        condition = "input.tabs_rf == 'Model Performance Plots'",
        uiOutput("ui_rf_plots"),
        conditionalPanel(
          condition = "input.rf_plots == 'dashboard'",
          uiOutput("ui_rf_nrobs")
        ),
        conditionalPanel(
          condition = "input.rf_plots == 'pdp' | input.rf_plots == 'pred_plot'",
          uiOutput("ui_rf_incl"),
          uiOutput("ui_rf_incl_int")
        )
        # conditionalPanel(
        #   condition = "input.rf_plots == 'pdp'",
        #   checkboxInput("rf_qtiles", "Show quintiles", state_init("rf_qtiles", FALSE))
        # )
      ),
      # conditionalPanel(
      #   condition = "input.tabs_rf == 'Summary'",
      #   tags$table(
      #     tags$td(uiOutput("ui_rf_store_res_name")),
      #     tags$td(actionButton("rf_store_res", "Store", icon = icon("plus", verify_fa = FALSE)), class = "top")
      #   )
      # )
    ),
    help_and_report(
      modal_title = "Random Forest",
      fun_name = "rf",
      help_file = inclMD(file.path(getOption("radiant.path.model"), "app/tools/help/rforest.md"))
    )
  )
})
observeEvent(input$cv_rf_run, {
  # Extract hyperparameters from the inputs
  mtry_vals <- as.numeric(unlist(strsplit(input$cv_rf_mtry, ",")))
  num_trees_vals <- as.numeric(unlist(strsplit(input$cv_rf_num_trees, ",")))
  min_node_size_vals <- as.numeric(unlist(strsplit(input$cv_rf_min_node_size, ",")))
  sample_fraction_vals <- as.numeric(unlist(strsplit(input$cv_rf_sample_fraction, ",")))

  # Perform cross-validation using the cv.rforest function
  result <- cv.rforest(
    object = .rf(),  # Use the current random forest model
    mtry = mtry_vals,
    num.trees = num_trees_vals,
    min.node.size = min_node_size_vals,
    sample.fraction = sample_fraction_vals,
    seed = input$cv_rf_seed
  )

  # Render the cross-validation results
  output$cv_rforest_results <- renderPrint({
    result$results
  })
  output$cv_rforest_message <- renderText({
    result$message
  })
})

rf_plot <- reactive({
  if (rf_available() != "available") {
    return()
  }
  if (is.empty(input$rf_plots, "none")) {
    return()
  }
  res <- .rf()
  if (is.character(res)) {
    return()
  }
  nr_vars <- length(res$evar)
  plot_height <- 500
  plot_width <- 650
  if ("dashboard" %in% input$rf_plots) {
    plot_height <- 750
  } else if (input$rf_plots %in% c("pdp", "pred_plot")) {
    nr_vars <- length(input$rf_incl) + length(input$rf_incl_int)
    plot_height <- max(250, ceiling(nr_vars / 2) * 250)
    if (length(input$rf_incl_int) > 0) {
      plot_width <- plot_width + min(2, length(input$rf_incl_int)) * 90
    }
  } else if ("vimp" %in% input$rf_plots) {
    plot_height <- max(500, nr_vars * 35)
  } else if ("vip" %in% input$rf_plots) {
    plot_height <- max(500, nr_vars * 35)
  }

  list(plot_width = plot_width, plot_height = plot_height)
})

rf_plot_width <- function() {
  rf_plot() %>%
    (function(x) if (is.list(x)) x$plot_width else 650)
}

rf_plot_height <- function() {
  rf_plot() %>%
    (function(x) if (is.list(x)) x$plot_height else 500)
}

rf_pred_plot_height <- function() {
  if (input$rf_pred_plot) 500 else 1
}

## output is called from the main radiant ui.R
output$rf <- renderUI({
  register_print_output("summary_rf", ".summary_rf")
  register_print_output("predict_rf", ".predict_print_rf")
  register_plot_output(
    "predict_plot_rf", ".predict_plot_rf",
    height_fun = "rf_pred_plot_height"
  )
  register_plot_output(
    "plot_rf", ".plot_rf",
    height_fun = "rf_plot_height",
    width_fun = "rf_plot_width"
  )

  ## three separate tabs
  rf_output_panels <- tabsetPanel(
    id = "tabs_rf",
    tabPanel(
      "Model Summary",
      verbatimTextOutput("summary_rf"),
      br(),
      h4("Cross Validation Results"),
      verbatimTextOutput("cv_rforest_results"),
      verbatimTextOutput("cv_rforest_message"),
      HTML("
        <h4>Interpreting Model Performance Metrics</h4>
        <h5>Out-of-Bag (OOB) Prediction Error</h5>
        <p>
          The OOB prediction error is an estimate of the prediction error for a Random Forest model. It is calculated using the samples that were not used during the training of each tree (out-of-bag samples). Here's how you can interpret it:
          <ul>
            <li><b>Low OOB Error:</b> Indicates that the model performs well on unseen data, suggesting good generalization.</li>
            <li><b>High OOB Error:</b> Suggests that the model may not be performing well, possibly due to overfitting (model is too complex) or underfitting (model is too simple).</li>
          </ul>
        </p>
        <h5>R-squared (R²) Value</h5>
        <p>
          The R² value is a measure of how well the observed outcomes are replicated by the model, based on the proportion of total variation of outcomes explained by the model. Here's how you can evaluate it:
          <ul>
            <li><b>R² = 1:</b> Perfect fit. The model explains all the variability of the response data around its mean.</li>
            <li><b>0 < R² < 1:</b> The model explains some but not all of the variability in the response data. Higher values indicate better model performance.</li>
            <li><b>R² = 0:</b> The model does not explain any of the variability in the response data.</li>
            <li><b>R² < 0:</b> The model performs worse than a horizontal line (mean of the response), indicating a very poor fit.</li>
          </ul>
        </p>
        <h5>Evaluation Tips</h5>
        <p>
          <ul>
            <li>Compare the OOB prediction error and R² value with those from other models to determine which model performs best.</li>
            <li>Consider the context and domain-specific requirements. For some applications, a lower R² value might still be acceptable.</li>
            <li>Use cross-validation or additional test data to further validate model performance.</li>
          </ul>
        </p>
      ")
    ),
    tabPanel(
      "Model Performance Plots",  # Moved this tab to be the second one
      download_link("dlp_rf"),
      plotOutput("plot_rf", width = "100%", height = "100%"),
      HTML("
        <h4>Interpreting Model Performance Plots</h4>
        <p>
          These plots help to visualize various aspects of the Random Forest model's performance:
          <ul>
            <li><b>Permutation Importance:</b> Shows the importance of each variable based on how much it contributes to the model's accuracy.</li>
            <li><b>Prediction Plots:</b> Visualizes the relationship between predicted values and actual outcomes.</li>
            <li><b>Partial Dependence Plots:</b> Illustrates the marginal effect of selected variables on the prediction outcome.</li>
            <li><b>Dashboard:</b> Provides a comprehensive overview of model performance metrics and diagnostics.</li>
          </ul>
        </p>
      ")
    ),
    tabPanel(
      "Predictions",  # Moved this tab to be the third one
      verbatimTextOutput("predict_rf"),
      HTML("
        <h4>Interpreting Prediction Values</h4>
        <h5>For Classification Trees</h5>
        <p>
          In a classification tree, each prediction is a probability distribution over the possible classes. Here's how to interpret it:
          <ul>
            <li>Each column represents a possible class label.</li>
            <li>Each cell contains the probability that the given observation belongs to that class.</li>
            <li>The class with the highest probability is the predicted class for that observation.</li>
          </ul>
        </p>
        <h5>For Regression Trees</h5>
        <p>
          In a regression tree, each prediction is a continuous value representing the estimated response. Here's how to interpret it:
          <ul>
            <li>Each row represents a single observation.</li>
            <li>The predicted value in each row is the model's estimate for the response variable for that observation.</li>
            <li>Compare the predicted values to the actual values to assess the model's performance.</li>
          </ul>
        </p>
      "),
      conditionalPanel(
        condition = "input.rf_pred_plot == true",
        download_link("dlp_rf_pred"),
        plotOutput("predict_plot_rf", width = "100%", height = "100%")
      ),
      download_link("dl_rf_pred"), br()
    )
  )

  stat_tab_panel(
    menu = "Model > Estimate",
    tool = "Random Forest",
    tool_ui = "ui_rf",
    output_panels = rf_output_panels
  )

})


rf_available <- reactive({
  req(input$rf_type)
  if (not_available(input$rf_rvar)) {
    if (input$rf_type == "classification") {
      "This analysis requires a response variable with two levels and one\nor more explanatory variables. If these variables are not available\nplease select another dataset.\n\n" %>%
        suggest_data("titanic")
    } else {
      "This analysis requires a response variable of type integer\nor numeric and one or more explanatory variables.\nIf these variables are not available please select another dataset.\n\n" %>%
        suggest_data("diamonds")
    }
  } else if (not_available(input$rf_evar)) {
    if (input$rf_type == "classification") {
      "Please select one or more explanatory variables.\n\n" %>%
        suggest_data("titanic")
    } else {
      "Please select one or more explanatory variables.\n\n" %>%
        suggest_data("diamonds")
    }
  } else {
    "available"
  }
})

.rf <- eventReactive(input$rf_run, {
  rfi <- rf_inputs()
  rfi$envir <- r_data

  if (is.empty(rfi$mtry)) rfi$mtry <- 1
  nr_evar <- length(rfi$evar)
  if (rfi$mtry > nr_evar) {
    rfi$mtry <- nr_evar
    updateNumericInput(session, "rf_mtry", value = nr_evar)
  } else if (rfi$mtry < 0) {
    rfi$mtry <- 1
    updateNumericInput(session, "rf_mtry", value = 1)
  }

  if (is.empty(rfi$num.trees)) rfi$num.trees <- 100
  if (is.empty(rfi$min.node.size)) rfi$min.node.size <- 1
  if (is.empty(rfi$sample.fraction)) rfi$sample.fraction <- 1

  withProgress(
    message = "Estimating random forest", value = 1,
    do.call(rforest, rfi)
  )
})

.summary_rf <- reactive({
  if (not_pressed(input$rf_run)) {
    return("** Press the Estimate button to estimate the model **")
  }
  if (rf_available() != "available") {
    return(rf_available())
  }
  summary(.rf())
})

.predict_rf <- reactive({
  if (not_pressed(input$rf_run)) {
    return("** Press the Estimate button to estimate the model **")
  }
  if (rf_available() != "available") {
    return(rf_available())
  }
  if (is.empty(input$rf_predict, "none")) {
    return("** Select prediction input **")
  } else if ((input$rf_predict == "data" || input$rf_predict == "datacmd") && is.empty(input$rf_pred_data)) {
    return("** Select data for prediction **")
  } else if (input$rf_predict == "cmd" && is.empty(input$rf_pred_cmd)) {
    return("** Enter prediction commands **")
  }

  withProgress(message = "Generating predictions", value = 1, {
    rfi <- rf_pred_inputs()
    rfi$object <- .rf()
    rfi$envir <- r_data
    rfi$OOB <- input$dataset == input$rf_pred_data &&
      (input$rf_predict == "data" || (input$rf_predict == "datacmd" && is.empty(input$rf_pred_cmd))) &&
      ((is.empty(input$data_filter) && is.empty(input$data_rows)) || input$show_filter == FALSE) &&
      pressed(input$rf_run)
    do.call(predict, rfi)
  })
})

.predict_print_rf <- reactive({
  .predict_rf() %>%
    (function(x) if (is.character(x)) cat(x, "\n") else print(x))
})

.predict_plot_rf <- reactive({
  req(
    pressed(input$rf_run), input$rf_pred_plot,
    available(input$rf_xvar),
    !is.empty(input$rf_predict, "none")
  )

  withProgress(message = "Generating prediction plot", value = 1, {
    do.call(plot, c(list(x = .predict_rf()), rf_pred_plot_inputs()))
  })
})

.plot_rf <- reactive({
  if (not_pressed(input$rf_run)) {
    return("** Press the Estimate button to estimate the model **")
  }
  if (rf_available() != "available") {
    return(rf_available())
  }
  if (is.empty(input$rf_plots, "none")) {
    return("Please select a random forest plot from the drop-down menu")
  }
  pinp <- rf_plot_inputs()
  pinp$shiny <- TRUE
  if (input$rf_plots == "dashboard") {
    req(input$rf_nrobs)
  }
  check_for_pdp_pred_plots("rf")
  withProgress(message = "Generating plots", value = 1, {
    do.call(plot, c(list(x = .rf()), pinp))
  })
})

# observeEvent(input$rf_store_res, {
#   req(pressed(input$rf_run))
#   robj <- .rf()
#   if (!is.list(robj)) return()
#   fixed <- fix_names(input$rf_store_res_name)
#   updateTextInput(session, "rf_store_res_name", value = fixed)
#   withProgress(
#     message = "Storing residuals", value = 1,
#     r_data[[input$dataset]] <- store(r_data[[input$dataset]], robj, name = fixed)
#   )
# })

observeEvent(input$rf_store_pred, {
  req(!is.empty(input$rf_pred_data), pressed(input$rf_run))
  pred <- .predict_rf()
  if (is.null(pred)) {
    return()
  }
  fixed <- unlist(strsplit(input$rf_store_pred_name, "(\\s*,\\s*|\\s*;\\s*)")) %>%
    fix_names() %>%
    paste0(collapse = ", ")
  updateTextInput(session, "rf_store_pred_name", value = fixed)
  withProgress(
    message = "Storing predictions", value = 1,
    r_data[[input$rf_pred_data]] <- store(
      r_data[[input$rf_pred_data]], pred,
      name = fixed
    )
  )
})

rf_report <- function() {
  if (is.empty(input$rf_rvar)) {
    return(invisible())
  }

  outputs <- c("summary")
  inp_out <- list("", "")
  figs <- FALSE

  if (!is.empty(input$rf_plots, "none")) {
    inp <- check_plot_inputs(rf_plot_inputs())
    inp_out[[2]] <- clean_args(inp, rf_plot_args[-1])
    inp_out[[2]]$custom <- FALSE
    outputs <- c(outputs, "plot")
    figs <- TRUE
  }

  # if (!is.empty(input$rf_store_res_name)) {
  #   fixed <- fix_names(input$rf_store_res_name)
  #   updateTextInput(session, "rf_store_res_name", value = fixed)
  #   xcmd <- paste0(input$dataset, " <- store(", input$dataset, ", result, name = \"", fixed, "\")\n")
  # } else {
  #   xcmd <- ""
  # }
  xcmd <- ""

  if (!is.empty(input$rf_predict, "none") &&
      (!is.empty(input$rf_pred_data) || !is.empty(input$rf_pred_cmd))) {
    pred_args <- clean_args(rf_pred_inputs(), rf_pred_args[-1])

    if (!is.empty(pred_args$pred_cmd)) {
      pred_args$pred_cmd <- strsplit(pred_args$pred_cmd, ";\\s*")[[1]]
    } else {
      pred_args$pred_cmd <- NULL
    }

    if (is.empty(pred_args$pred_cmd) && !is.empty(pred_args$pred_data)) {
      pred_args$OOB <- input$dataset == pred_args$pred_data &&
        ((is.empty(input$data_filter) && is.empty(input$data_rows)) || input$show_filter == FALSE) &&
        pressed(input$rf_run)
    }

    if (!is.empty(pred_args$pred_data)) {
      pred_args$pred_data <- as.symbol(pred_args$pred_data)
    } else {
      pred_args$pred_data <- NULL
    }

    inp_out[[2 + figs]] <- pred_args
    outputs <- c(outputs, "pred <- predict")
    xcmd <- paste0(xcmd, "print(pred, n = 10)")
    if (input$rf_predict %in% c("data", "datacmd")) {
      fixed <- fix_names(input$rf_store_pred_name)
      updateTextInput(session, "rf_store_pred_name", value = fixed)
      xcmd <- paste0(
        xcmd, "\n", input$rf_pred_data, " <- store(",
        input$rf_pred_data, ", pred, name = \"", fixed, "\")"
      )
    }

    if (input$rf_pred_plot && !is.empty(input$rf_xvar)) {
      inp_out[[3 + figs]] <- clean_args(rf_pred_plot_inputs(), rf_pred_plot_args[-1])
      inp_out[[3 + figs]]$result <- "pred"
      outputs <- c(outputs, "plot")
      figs <- TRUE
    }
  }

  rfi <- rf_inputs()
  if (input$rf_type == "regression") {
    rfi$lev <- NULL
  }

  update_report(
    inp_main = clean_args(rfi, rf_args),
    fun_name = "rforest",
    inp_out = inp_out,
    outputs = outputs,
    figs = figs,
    fig.width = rf_plot_width(),
    fig.height = rf_plot_height(),
    xcmd = xcmd
  )
}

dl_rf_pred <- function(path) {
  if (pressed(input$rf_run)) {
    write.csv(.predict_rf(), file = path, row.names = FALSE)
  } else {
    cat("No output available. Press the Estimate button to generate results", file = path)
  }
}

download_handler(
  id = "dl_rf_pred",
  fun = dl_rf_pred,
  fn = function() paste0(input$dataset, "_rf_pred"),
  type = "csv",
  caption = "Save predictions"
)

download_handler(
  id = "dlp_rf_pred",
  fun = download_handler_plot,
  fn = function() paste0(input$dataset, "_rf_pred"),
  type = "png",
  caption = "Save random forest prediction plot",
  plot = .predict_plot_rf,
  width = plot_width,
  height = rf_pred_plot_height
)

download_handler(
  id = "dlp_rf",
  fun = download_handler_plot,
  fn = function() paste0(input$dataset, "_rf"),
  type = "png",
  caption = "Save random forest plot",
  plot = .plot_rf,
  width = rf_plot_width,
  height = rf_plot_height
)

observeEvent(input$rf_report, {
  r_info[["latest_screenshot"]] <- NULL
  rf_report()
})

observeEvent(input$rf_screenshot, {
  r_info[["latest_screenshot"]] <- NULL
  radiant_screenshot_modal("modal_rf_screenshot")
})

observeEvent(input$modal_rf_screenshot, {
  rf_report()
  removeModal() ## remove shiny modal after save
})





