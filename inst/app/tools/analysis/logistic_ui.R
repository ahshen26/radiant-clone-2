logit_show_interactions <- c("None" = "", "2-way" = 2, "3-way" = 3)
logit_predict <- c(
  "None" = "none",
  "Data" = "data",
  "Command" = "cmd",
  "Data & Command" = "datacmd"
)
logit_check <- c(
  "Standardize" = "standardize", "Center" = "center",
  "Stepwise" = "stepwise-backward", "Robust" = "robust"
)
logit_sum_check <- c(
  "VIF" = "vif", "Confidence intervals" = "confint",
  "Odds" = "odds"
)
logit_plots <- c(
  "None" = "none", "Distribution" = "dist",
  "Correlations" = "correlations", "Scatter" = "scatter",
  "Permutation Importance" = "vip",
  "Prediction plots" = "pred_plot",
  "Partial Dependence" = "pdp",
  "Model fit" = "fit", "Coefficient (OR) plot" = "coef",
  "Influential observations" = "influence"
)
output$logit_plot_description <- renderText({
  switch(input$logit_plots,
         "dist" = "The distribution plot displays the distribution of the response and explanatory variables. Interpret by observing the distribution shape, central tendency, and spread. Look for outliers as they might influence the logistic regression model.",
         "correlations" = "The correlations plot shows the Pearson correlation coefficients between variables. Interpret by looking for high correlations, which indicate strong relationships. High multicollinearity can affect the model’s stability.",
         "scatter" = "Scatter plots display the relationship between pairs of variables. Interpret by assessing patterns that might suggest the presence of certain classes.",
         "vip" = "The permutation importance plot ranks variables based on their importance to the model. Focus on variables with higher importance scores as they explain most of the variance in the response.",
         "pred_plot" = "The prediction plot shows the model's predicted probabilities against observed data. Interpret by checking how well the predicted probabilities match with the actual outcomes.",
         "pdp" = "The partial dependence plot shows the effect of a single variable on the predicted probability. Interpret by analyzing how changes in this variable affect the predicted probability of the outcome, holding other variables constant.",
         "fit" = "The model fit plot shows how well the logistic model fits the data. Look for areas where the model may not perform well, particularly in regions with sparse data.",
         "coef" = "The coefficient (Odds Ratio) plot visualizes the estimated odds ratios for the model coefficients. Interpret by checking the direction and magnitude of the odds ratios, which indicate the change in odds for a one-unit change in the predictor.",
         "influence" = "This plot identifies influential observations that significantly impact the model. Investigate or possibly remove these points to improve model robustness."
  )
})

## list of function arguments
logit_args <- as.list(formals(logistic))

## list of function inputs selected by user
logit_inputs <- reactive({
  ## loop needed because reactive values don't allow single bracket indexing
  logit_args$data_filter <- if (input$show_filter) input$data_filter else ""
  logit_args$arr <- if (input$show_filter) input$data_arrange else ""
  logit_args$rows <- if (input$show_filter) input$data_rows else ""
  logit_args$dataset <- input$dataset
  for (i in r_drop(names(logit_args))) {
    logit_args[[i]] <- input[[paste0("logit_", i)]]
  }
  logit_args
})

logit_sum_args <- as.list(if (exists("summary.logistic")) {
  formals(summary.logistic)
} else {
  formals(radiant.model:::summary.logistic)
})

## list of function inputs selected by user
logit_sum_inputs <- reactive({
  ## loop needed because reactive values don't allow single bracket indexing
  for (i in names(logit_sum_args)) {
    logit_sum_args[[i]] <- input[[paste0("logit_", i)]]
  }
  logit_sum_args
})

logit_plot_args <- as.list(if (exists("plot.logistic")) {
  formals(plot.logistic)
} else {
  formals(radiant.model:::plot.logistic)
})

## list of function inputs selected by user
logit_plot_inputs <- reactive({
  ## loop needed because reactive values don't allow single bracket indexing
  for (i in names(logit_plot_args)) {
    logit_plot_args[[i]] <- input[[paste0("logit_", i)]]
  }

  # cat(paste0(names(logit_plot_args), " ", logit_plot_args, collapse = ", "), file = stderr(), "\n")
  logit_plot_args
})

logit_pred_args <- as.list(if (exists("predict.logistic")) {
  formals(predict.logistic)
} else {
  formals(radiant.model:::predict.logistic)
})

# list of function inputs selected by user
logit_pred_inputs <- reactive({
  # loop needed because reactive values don't allow single bracket indexing
  for (i in names(logit_pred_args)) {
    logit_pred_args[[i]] <- input[[paste0("logit_", i)]]
  }

  logit_pred_args$pred_cmd <- logit_pred_args$pred_data <- ""
  if (input$logit_predict == "cmd") {
    logit_pred_args$pred_cmd <- gsub("\\s{2,}", " ", input$logit_pred_cmd) %>%
      gsub(";\\s+", ";", .) %>%
      gsub("\"", "\'", .)
  } else if (input$logit_predict == "data") {
    logit_pred_args$pred_data <- input$logit_pred_data
  } else if (input$logit_predict == "datacmd") {
    logit_pred_args$pred_cmd <- gsub("\\s{2,}", " ", input$logit_pred_cmd) %>%
      gsub(";\\s+", ";", .) %>%
      gsub("\"", "\'", .)
    logit_pred_args$pred_data <- input$logit_pred_data
  }

  ## setting value for prediction interval type
  logit_pred_args$interval <- "confidence"

  logit_pred_args
})

logit_pred_plot_args <- as.list(if (exists("plot.model.predict")) {
  formals(plot.model.predict)
} else {
  formals(radiant.model:::plot.model.predict)
})


# list of function inputs selected by user
logit_pred_plot_inputs <- reactive({
  # loop needed because reactive values don't allow single bracket indexing
  for (i in names(logit_pred_plot_args)) {
    logit_pred_plot_args[[i]] <- input[[paste0("logit_", i)]]
  }
  logit_pred_plot_args
})

output$ui_logit_rvar <- renderUI({
  withProgress(message = "Acquiring variable information", value = 1, {
    vars <- two_level_vars()
  })
  selectInput(
    inputId = "logit_rvar", label = "Response variable:", choices = vars,
    selected = state_single("logit_rvar", vars), multiple = FALSE
  )
})

output$ui_logit_lev <- renderUI({
  req(available(input$logit_rvar))
  levs <- .get_data()[[input$logit_rvar]] %>%
    as.factor() %>%
    levels()
  selectInput(
    inputId = "logit_lev", label = "Choose level:",
    choices = levs, selected = state_init("logit_lev")
  )
})

output$ui_logit_evar <- renderUI({
  req(available(input$logit_rvar))
  vars <- varnames()
  if (length(vars) > 0 && input$logit_rvar %in% vars) {
    vars <- vars[-which(vars == input$logit_rvar)]
  }

  selectInput(
    inputId = "logit_evar", label = "Explanatory variables:", choices = vars,
    selected = state_multiple("logit_evar", vars, isolate(input$logit_evar)),
    multiple = TRUE, size = min(10, length(vars)), selectize = FALSE
  )
})

output$ui_logit_incl <- renderUI({
  req(available(input$logit_evar))
  vars <- input$logit_evar
  if (input[["logit_plots"]] == "coef") {
    vars_init <- vars
  } else {
    vars_init <- c()
  }
  selectInput(
    inputId = "logit_incl", label = "Explanatory variables to include:", choices = vars,
    selected = state_multiple("logit_incl", vars, vars_init),
    multiple = TRUE, size = min(10, length(vars)), selectize = FALSE
  )
})

output$ui_logit_incl_int <- renderUI({
  req(available(input$logit_evar))
  choices <- character(0)
  vars <- input$logit_evar
  ## list of interaction terms to show
  if (length(vars) > 1) {
    choices <- c(choices, iterms(vars, 2))
  } else {
    updateSelectInput(session, "logit_incl_int", choices = choices, selected = choices)
    return()
  }
  selectInput(
    "logit_incl_int",
    label = "2-way interactions to explore:",
    choices = choices,
    selected = state_multiple("logit_incl_int", choices),
    multiple = TRUE,
    size = min(8, length(choices)),
    selectize = FALSE
  )
})

output$ui_logit_wts <- renderUI({
  req(available(input$logit_rvar), available(input$logit_evar))
  isNum <- .get_class() %in% c("integer", "numeric", "ts")
  vars <- varnames()[isNum]
  if (length(vars) > 0 && any(vars %in% input$logit_evar)) {
    vars <- base::setdiff(vars, input$logit_evar)
    names(vars) <- varnames() %>%
      {
        .[match(vars, .)]
      } %>%
      names()
  }
  vars <- c("None", vars)

  selectInput(
    inputId = "logit_wts", label = "Weights:", choices = vars,
    selected = state_single("logit_wts", vars),
    multiple = FALSE
  )
})

output$ui_logit_test_var <- renderUI({
  req(available(input$logit_evar))
  vars <- input$logit_evar
  if (!is.null(input$logit_int)) vars <- c(vars, input$logit_int)
  selectizeInput(
    inputId = "logit_test_var", label = "Variables to test:",
    choices = vars,
    selected = state_multiple("logit_test_var", vars, isolate(input$logit_test_var)),
    multiple = TRUE,
    options = list(placeholder = "None", plugins = list("remove_button"))
  )
})

## not clear why this is needed because state_multiple should handle this
observeEvent(is.null(input$logit_test_var), {
  if ("logit_test_var" %in% names(input)) r_state$logit_test_var <<- NULL
})

output$ui_logit_show_interactions <- renderUI({
  # choices <- logit_show_interactions[1:max(min(3, length(input$logit_evar)), 1)]
  vars <- input$logit_evar
  isNum <- .get_class() %in% c("integer", "numeric", "ts")
  if (any(vars %in% varnames()[isNum])) {
    choices <- logit_show_interactions[1:3]
  } else {
    choices <- logit_show_interactions[1:max(min(3, length(input$logit_evar)), 1)]
  }
  radioButtons(
    inputId = "logit_show_interactions", label = "Interactions:",
    choices = choices, selected = state_init("logit_show_interactions"),
    inline = TRUE
  )
})

output$ui_logit_show_interactions <- renderUI({
  vars <- input$logit_evar
  isNum <- .get_class() %in% c("integer", "numeric", "ts")
  if (any(vars %in% varnames()[isNum])) {
    choices <- logit_show_interactions[1:3]
  } else {
    choices <- logit_show_interactions[1:max(min(3, length(input$logit_evar)), 1)]
  }
  radioButtons(
    inputId = "logit_show_interactions", label = "Interactions:",
    choices = choices, selected = state_init("logit_show_interactions"),
    inline = TRUE
  )
})

output$ui_logit_int <- renderUI({
  choices <- character(0)
  if (isolate("logit_show_interactions" %in% names(input)) &&
      is.empty(input$logit_show_interactions)) {
  } else if (is.empty(input$logit_show_interactions)) {
    return()
  } else {
    vars <- input$logit_evar
    if (not_available(vars)) {
      return()
    } else {
      ## quadratic and qubic terms
      isNum <- .get_class() %in% c("integer", "numeric", "ts")
      isNum <- intersect(vars, varnames()[isNum])
      if (length(isNum) > 0) {
        choices <- qterms(isNum, input$logit_show_interactions)
      }
      ## list of interaction terms to show
      if (length(vars) > 1) {
        choices <- c(choices, iterms(vars, input$logit_show_interactions))
      }
      if (length(choices) == 0) {
        return()
      }
    }
  }

  selectInput(
    "logit_int",
    label = NULL,
    choices = choices,
    selected = state_init("logit_int"),
    multiple = TRUE,
    size = min(8, length(choices)),
    selectize = FALSE
  )
})

## reset prediction and plot settings when the dataset changes
observeEvent(input$dataset, {
  updateSelectInput(session = session, inputId = "logit_predict", selected = "none")
  updateSelectInput(session = session, inputId = "logit_plots", selected = "none")
})

output$ui_logit_predict_plot <- renderUI({
  predict_plot_controls("logit")
})

output$ui_logit_nrobs <- renderUI({
  nrobs <- nrow(.get_data())
  choices <- c("1,000" = 1000, "5,000" = 5000, "10,000" = 10000, "All" = -1) %>%
    .[. < nrobs]
  selectInput(
    "logit_nrobs", "Number of data points plotted:",
    choices = choices,
    selected = state_single("logit_nrobs", choices, 1000)
  )
})

output$ui_logit_store_res_name <- renderUI({
  req(input$dataset)
  textInput("logit_store_res_name", "Store residuals:", "", placeholder = "Provide variable name")
})

## add a spinning refresh icon if the model needs to be (re)estimated
run_refresh(logit_args, "logit", tabs = "tabs_logistic", label = "Estimate model", relabel = "Re-estimate model")

output$ui_logistic <- renderUI({
  req(input$dataset)
  tagList(
    conditionalPanel(
      condition = "input.tabs_logistic == 'Model Summary'",
      wellPanel(
        actionButton("logit_run", "Estimate model", width = "100%", icon = icon("play", verify_fa = FALSE), class = "btn-success")
      )
    ),
    wellPanel(
      conditionalPanel(
        condition = "input.tabs_logistic == 'Model Summary'",
        uiOutput("ui_logit_rvar"),
        uiOutput("ui_logit_lev"),
        uiOutput("ui_logit_evar"),
        uiOutput("ui_logit_wts"),
        conditionalPanel(
          condition = "input.logit_evar != null",
          uiOutput("ui_logit_show_interactions"),
          conditionalPanel(
            condition = "input.logit_show_interactions != ''",
            uiOutput("ui_logit_int")
          ),
          uiOutput("ui_logit_test_var"),
          checkboxGroupInput(
            "logit_check", NULL, logit_check,
            selected = state_group("logit_check"), inline = TRUE
          ),
          checkboxGroupInput(
            "logit_sum_check", NULL, logit_sum_check,
            selected = state_group("logit_sum_check", ""), inline = TRUE
          )
        )
      ),
      conditionalPanel(
        condition = "input.tabs_logistic == 'Predictions'",
        selectInput(
          "logit_predict",
          label = "Prediction input type:", logit_predict,
          selected = state_single("logit_predict", logit_predict, "none")
        ),
        conditionalPanel(
          "input.logit_predict == 'data' | input.logit_predict == 'datacmd'",
          selectizeInput(
            inputId = "logit_pred_data", label = "Prediction data:",
            choices = c("None" = "", r_info[["datasetlist"]]),
            selected = state_single("logit_pred_data", c("None" = "", r_info[["datasetlist"]])),
            multiple = FALSE
          )
        ),
        conditionalPanel(
          "input.logit_predict == 'cmd' | input.logit_predict == 'datacmd'",
          returnTextAreaInput(
            "logit_pred_cmd", "Prediction command:",
            value = state_init("logit_pred_cmd", ""),
            rows = 3,
            placeholder = "Type a formula to set values for model variables (e.g., class = '1st'; gender = 'male') and press return"
          )
        ),
        conditionalPanel(
          condition = "input.logit_predict != 'none'",
          checkboxInput("logit_pred_plot", "Plot predictions", state_init("logit_pred_plot", FALSE)),
          conditionalPanel(
            "input.logit_pred_plot == true",
            uiOutput("ui_logit_predict_plot")
          )
        ),
        ## only show if full data is used for prediction
        conditionalPanel(
          "input.logit_predict == 'data' | input.logit_predict == 'datacmd'",
          tags$table(
            tags$td(textInput("logit_store_pred_name", "Store predictions:", state_init("logit_store_pred_name", "pred_logit"))),
            tags$td(actionButton("logit_store_pred", "Store", icon = icon("plus", verify_fa = FALSE)), class = "top")
          )
        )
      ),
      conditionalPanel(
        condition = "input.tabs_logistic == 'Model Performance Plots'",
        selectInput(
          "logit_plots", "Plots:",
          choices = logit_plots,
          selected = state_single("logit_plots", logit_plots)
        ),
        conditionalPanel(
          condition = "input.logit_plots == 'coef' | input.logit_plots == 'pdp' | input.logit_plots == 'pred_plot'",
          uiOutput("ui_logit_incl"),
          conditionalPanel(
            condition = "input.logit_plots == 'coef'",
            checkboxInput("logit_intercept", "Include intercept", state_init("logit_intercept", FALSE))
          ),
          conditionalPanel(
            condition = "input.logit_plots == 'pdp' | input.logit_plots == 'pred_plot'",
            uiOutput("ui_logit_incl_int")
          )
        ),
        # conditionalPanel(
        #   condition = "input.logit_plots == 'coef'",
        #   uiOutput("ui_logit_incl"),
        #   checkboxInput("logit_intercept", "Include intercept", state_init("logit_intercept", FALSE))
        # ),
        conditionalPanel(
          condition = "input.logit_plots == 'correlations' |
                       input.logit_plots == 'scatter'",
          uiOutput("ui_logit_nrobs")
        )
      ),
      # Using && to check that input.logit_sum_check is not null (must be &&)
      conditionalPanel(
        condition = "(input.tabs_logistic == 'Model Summary' && input.logit_sum_check != undefined && (input.logit_sum_check.indexOf('confint') >= 0 || input.logit_sum_check.indexOf('odds') >= 0)) ||
                     (input.tabs_logistic == 'Predictions' && input.logit_predict != 'none') ||
                     (input.tabs_logistic == 'Model Performance Plots' && input.logit_plots == 'coef')",
        sliderInput(
          "logit_conf_lev", "Confidence level:",
          min = 0.80,
          max = 0.99, value = state_init("logit_conf_lev", .95),
          step = 0.01
        )
      ),
      conditionalPanel(
        condition = "input.tabs_logistic == 'Model Summary'",
        tags$table(
          # tags$td(textInput("logit_store_res_name", "Store residuals:", state_init("logit_store_res_name", "residuals_logit"))),
          tags$td(uiOutput("ui_logit_store_res_name")),
          tags$td(actionButton("logit_store_res", "Store", icon = icon("plus", verify_fa = FALSE)), class = "top")
        )
      )
    ),
    help_and_report(
      modal_title = "Logistic regression (GLM)", fun_name = "logistic",
      help_file = inclRmd(file.path(getOption("radiant.path.model"), "app/tools/help/logistic.Rmd"))
    )
  )
})

logit_plot <- reactive({
  if (logit_available() != "available") {
    return()
  }
  if (is.empty(input$logit_plots, "none")) {
    return()
  }

  plot_height <- 500
  plot_width <- 650
  nr_vars <- length(input$logit_evar) + 1

  if (input$logit_plots == "dist") {
    plot_height <- (plot_height / 2) * ceiling(nr_vars / 2)
  } else if (input$logit_plots == "fit") {
    plot_width <- 1.5 * plot_width
  } else if (input$logit_plots == "correlations") {
    plot_height <- 150 * nr_vars
    plot_width <- 150 * nr_vars
  } else if (input$logit_plots == "scatter") {
    plot_height <- 300 * nr_vars
  } else if (input$logit_plots == "coef") {
    incl <- paste0("^(", paste0(input$logit_incl, "[|]*", collapse = "|"), ")")
    nr_coeff <- sum(grepl(incl, .logistic()$coeff$label))
    plot_height <- 300 + 20 * nr_coeff
  } else if (input$logit_plots == "vip") {
    plot_height <- max(500, 30 * nr_vars)
  } else if (input$logit_plots %in% c("pdp", "pred_plot")) {
    nr_vars <- length(input$logit_incl) + length(input$logit_incl_int)
    plot_height <- max(250, ceiling(nr_vars / 2) * 250)
    if (length(input$logit_incl_int) > 0) {
      plot_width <- plot_width + min(2, length(input$logit_incl_int)) * 90
    }
  }
  list(plot_width = plot_width, plot_height = plot_height)
})

logit_plot_width <- function() {
  logit_plot() %>%
    (function(x) if (is.list(x)) x$plot_width else 650)
}

logit_plot_height <- function() {
  logit_plot() %>%
    (function(x) if (is.list(x)) x$plot_height else 650)
}

logit_pred_plot_height <- function() {
  if (input$logit_pred_plot) 500 else 1
}

## output is called from the main radiant ui.R
output$logistic <- renderUI({
  register_print_output("summary_logistic", ".summary_logistic")
  register_print_output("predict_logistic", ".predict_print_logistic")
  register_plot_output(
    "predict_plot_logistic", ".predict_plot_logistic",
    height_fun = "logit_pred_plot_height"
  )
  register_plot_output(
    "plot_logistic", ".plot_logistic",
    height_fun = "logit_plot_height",
    width_fun = "logit_plot_width"
  )

  ## two separate tabs
  logit_output_panels <- tabsetPanel(
    id = "tabs_logistic",
    tabPanel(
      "Model Summary",
      download_link("dl_logit_coef"), br(),
      verbatimTextOutput("summary_logistic")
    ),
    tabPanel(
      "Model Performance Plots",
      download_link("dlp_logistic"),
      plotOutput("plot_logistic", width = "100%", height = "100%"),
      textOutput("logit_plot_description")  # Description appears right after the plot
    ),
    tabPanel(
      "Predictions",
      conditionalPanel(
        "input.logit_pred_plot == true",
        download_link("dlp_logit_pred"),
        plotOutput("predict_plot_logistic", width = "100%", height = "100%")
      ),
      download_link("dl_logit_pred"), br(),
      verbatimTextOutput("predict_logistic")
    )
  )


  stat_tab_panel(
    menu = "Model > Estimate",
    tool = "Logistic regression (GLM)",
    tool_ui = "ui_logistic",
    output_panels = logit_output_panels
  )
})

logit_available <- reactive({
  if (not_available(input$logit_rvar)) {
    "This analysis requires a response variable with two levels and one\nor more explanatory variables. If these variables are not available\nplease select another dataset.\n\n" %>%
      suggest_data("titanic")
  } else if (not_available(input$logit_evar)) {
    "Please select one or more explanatory variables.\n\n" %>%
      suggest_data("titanic")
  } else {
    "available"
  }
})

.logistic <- eventReactive(input$logit_run, {
  req(input$logit_lev)
  req(input$logit_wts == "None" || available(input$logit_wts))
  withProgress(message = "Estimating model", value = 1, {
    lgi <- logit_inputs()
    lgi$envir <- r_data
    do.call(logistic, lgi)
  })
})

.summary_logistic <- reactive({
  if (not_pressed(input$logit_run)) {
    return("** Press the Estimate button to estimate the model **")
  }
  if (logit_available() != "available") {
    return(logit_available())
  }
  do.call(summary, c(list(object = .logistic()), logit_sum_inputs()))
})

.predict_logistic <- reactive({
  if (not_pressed(input$logit_run)) {
    return("** Press the Estimate button to estimate the model **")
  }
  if (logit_available() != "available") {
    return(logit_available())
  }
  if (is.empty(input$logit_predict, "none")) {
    return("** Select prediction input **")
  }
  if ((input$logit_predict == "data" || input$logit_predict == "datacmd") && is.empty(input$logit_pred_data)) {
    return("** Select data for prediction **")
  }
  if (input$logit_predict == "cmd" && is.empty(input$logit_pred_cmd)) {
    return("** Enter prediction commands **")
  }

  withProgress(message = "Generating predictions", value = 1, {
    lgi <- logit_pred_inputs()
    lgi$object <- .logistic()
    lgi$envir <- r_data
    do.call(predict, lgi)
  })
})

.predict_print_logistic <- reactive({
  .predict_logistic() %>%
    {
      if (is.character(.)) cat(., "\n") else print(.)
    }
})

.predict_plot_logistic <- reactive({
  req(
    pressed(input$logit_run), input$logit_pred_plot,
    available(input$logit_xvar),
    !is.empty(input$logit_predict, "none")
  )

  withProgress(message = "Generating prediction plot", value = 1, {
    do.call(plot, c(list(x = .predict_logistic()), logit_pred_plot_inputs()))
  })
})

# pred_pdp_
# logit_available <- reactive({
#   if (not_available(input$logit_rvar)) {
#     "This analysis requires a response variable with two levels and one\nor more explanatory variables. If these variables are not available\nplease select another dataset.\n\n" %>%
#       suggest_data("titanic")
#   } else if (not_available(input$logit_evar)) {
#     "Please select one or more explanatory variables.\n\n" %>%
#       suggest_data("titanic")
#   } else {
#     "available"
#   }
# })


check_for_pdp_pred_plots <- function(mod_type) {
  if (input[[glue("{mod_type}_plots")]] %in% c("pdp", "pred_plot")) {
    req(sum(input[[glue("{mod_type}_incl")]] %in% input[[glue("{mod_type}_evar")]]) == length(input[[glue("{mod_type}_incl")]]))
    if (length(input[[glue("{mod_type}_incl_int")]]) > 0) {
      incl_int <- unique(unlist(strsplit(input[[glue("{mod_type}_incl_int")]], ":")))
      req(sum(incl_int %in% input[[glue("{mod_type}_evar")]]) == length(incl_int))
    }
  }
}

.plot_logistic <- reactive({
  if (not_pressed(input$logit_run)) {
    return("** Press the Estimate button to estimate the model **")
  } else if (is.empty(input$logit_plots, "none")) {
    return("Please select a logistic regression plot from the drop-down menu")
  } else if (logit_available() != "available") {
    return(logit_available())
  }

  if (input$logit_plots %in% c("correlations", "scatter")) req(input$logit_nrobs)
  check_for_pdp_pred_plots("logit")

  if (input$logit_plots == "correlations") {
    capture_plot(do.call(plot, c(list(x = .logistic()), logit_plot_inputs())))
  } else {
    withProgress(message = "Generating plots", value = 1, {
      do.call(plot, c(list(x = .logistic()), logit_plot_inputs(), shiny = TRUE))
    })
  }
})

logistic_report <- function() {
  outputs <- c("summary")
  inp_out <- list("", "")
  inp_out[[1]] <- clean_args(logit_sum_inputs(), logit_sum_args[-1])
  figs <- FALSE
  if (!is.empty(input$logit_plots, "none")) {
    inp <- check_plot_inputs(logit_plot_inputs())
    inp_out[[2]] <- clean_args(inp, logit_plot_args[-1])
    inp_out[[2]]$custom <- FALSE
    outputs <- c(outputs, "plot")
    figs <- TRUE
  }

  if (!is.empty(input$logit_store_res_name)) {
    fixed <- fix_names(input$logit_store_res_name)
    updateTextInput(session, "logit_store_res_name", value = fixed)
    xcmd <- paste0(input$dataset, " <- store(", input$dataset, ", result, name = \"", fixed, "\")\n")
  } else {
    xcmd <- ""
  }

  if (!is.empty(input$logit_predict, "none") &&
      (!is.empty(input$logit_pred_data) || !is.empty(input$logit_pred_cmd))) {
    pred_args <- clean_args(logit_pred_inputs(), logit_pred_args[-1])

    if (!is.empty(pred_args$pred_cmd)) {
      pred_args$pred_cmd <- strsplit(pred_args$pred_cmd, ";\\s*")[[1]]
    } else {
      pred_args$pred_cmd <- NULL
    }

    if (!is.empty(pred_args$pred_data)) {
      pred_args$pred_data <- as.symbol(pred_args$pred_data)
    } else {
      pred_args$pred_data <- NULL
    }

    inp_out[[2 + figs]] <- pred_args
    outputs <- c(outputs, "pred <- predict")

    xcmd <- paste0(xcmd, "print(pred, n = 10)")
    if (input$logit_predict %in% c("data", "datacmd")) {
      fixed <- unlist(strsplit(input$logit_store_pred_name, "(\\s*,\\s*|\\s*;\\s*)")) %>%
        fix_names() %>%
        deparse(., control = getOption("dctrl"), width.cutoff = 500L)
      xcmd <- paste0(
        xcmd, "\n", input$logit_pred_data, " <- store(",
        input$logit_pred_data, ", pred, name = ", fixed, ")"
      )
    }
    # xcmd <- paste0(xcmd, "\n# write.csv(pred, file = \"~/logit_predictions.csv\", row.names = FALSE)")

    if (input$logit_pred_plot && !is.empty(input$logit_xvar)) {
      inp_out[[3 + figs]] <- clean_args(logit_pred_plot_inputs(), logit_pred_plot_args[-1])
      inp_out[[3 + figs]]$result <- "pred"
      outputs <- c(outputs, "plot")
      figs <- TRUE
    }
  }

  update_report(
    inp_main = clean_args(logit_inputs(), logit_args),
    fun_name = "logistic",
    inp_out = inp_out,
    outputs = outputs,
    figs = figs,
    fig.width = logit_plot_width(),
    fig.height = logit_plot_height(),
    xcmd = xcmd
  )
}

observeEvent(input$logit_store_res, {
  req(pressed(input$logit_run))
  robj <- .logistic()
  if (!is.list(robj)) {
    return()
  }
  fixed <- fix_names(input$logit_store_res_name)
  updateTextInput(session, "logit_store_res_name", value = fixed)
  withProgress(
    message = "Storing residuals", value = 1,
    r_data[[input$dataset]] <- store(r_data[[input$dataset]], robj, name = fixed)
  )
})

observeEvent(input$logit_store_pred, {
  req(!is.empty(input$logit_pred_data), pressed(input$logit_run))
  pred <- .predict_logistic()
  if (is.null(pred)) {
    return()
  }
  fixed <- unlist(strsplit(input$logit_store_pred_name, "(\\s*,\\s*|\\s*;\\s*)")) %>%
    fix_names() %>%
    paste0(collapse = ", ")
  updateTextInput(session, "logit_store_pred_name", value = fixed)
  withProgress(
    message = "Storing predictions", value = 1,
    r_data[[input$logit_pred_data]] <- store(
      r_data[[input$logit_pred_data]], pred,
      name = fixed
    )
  )
})

dl_logit_coef <- function(path) {
  if (pressed(input$logit_run)) {
    write.coeff(.logistic(), file = path)
  } else {
    cat("No output available. Press the Estimate button to generate results", file = path)
  }
}

download_handler(
  id = "dl_logit_coef",
  fun = dl_logit_coef,
  fn = function() paste0(input$dataset, "_logit_coef"),
  type = "csv",
  caption = "Save coefficients"
)

dl_logit_pred <- function(path) {
  if (pressed(input$logit_run)) {
    write.csv(.predict_logistic(), file = path, row.names = FALSE)
  } else {
    cat("No output available. Press the Estimate button to generate results", file = path)
  }
}

download_handler(
  id = "dl_logit_pred",
  fun = dl_logit_pred,
  fn = function() paste0(input$dataset, "_logit_pred"),
  type = "csv",
  caption = "Save predictions"
)

download_handler(
  id = "dlp_logit_pred",
  fun = download_handler_plot,
  fn = function() paste0(input$dataset, "_logit_pred"),
  type = "png",
  caption = "Save logistic prediction plot",
  plot = .predict_plot_logistic,
  width = plot_width,
  height = logit_pred_plot_height
)

download_handler(
  id = "dlp_logistic",
  fun = download_handler_plot,
  fn = function() paste0(input$dataset, "_", input$logit_plots, "_logit"),
  type = "png",
  caption = "Save logistic plot",
  plot = .plot_logistic,
  width = logit_plot_width,
  height = logit_plot_height
)

observeEvent(input$logistic_report, {
  r_info[["latest_screenshot"]] <- NULL
  logistic_report()
})

observeEvent(input$logistic_screenshot, {
  r_info[["latest_screenshot"]] <- NULL
  radiant_screenshot_modal("modal_logistic_screenshot")
})

observeEvent(input$modal_logistic_screenshot, {
  logistic_report()
  removeModal() ## remove shiny modal after save
})
