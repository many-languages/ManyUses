# Many Uses progress dashboard. Run from this folder:
#   R -e "shiny::runApp('.')"
# or open this file in RStudio and click Run App.
#
# Local-file-based (see R/load_data.R's header) -- reads whatever's
# already on disk from the 02-Task / 05-Data pipelines, no live formr
# calls or credentials needed here.

library(shiny)
library(shinydashboard)
library(DT)
library(dplyr)

source("R/load_data.R")

# Progress bars are rendered as HTML (a width-scaled div) inside DT
# cells rather than a widget package -- ~4000 rows per language (see
# word_n_summary.csv) needs DT's pagination/search regardless, and DT
# already renders arbitrary HTML per cell, so no extra dependency for
# this alone.
progress_bar_html <- function(pct, label) {
  pct_display <- round(pct * 100)
  color <- if (pct >= 1) "#00a65a" else if (pct >= 0.5) "#f39c12" else "#dd4b39"
  sprintf(
    '<div style="background:#eee;border-radius:3px;width:100%%;height:18px;position:relative;">
       <div style="background:%s;width:%s%%;height:100%%;border-radius:3px;"></div>
       <span style="position:absolute;top:0;left:6px;font-size:11px;line-height:18px;">%s</span>
     </div>',
    color, pct_display, label
  )
}

languages <- load_languages()
active_languages <- languages$language[languages$status == "active"]
all_languages <- languages$language

ui <- dashboardPage(
  dashboardHeader(title = "Many Uses Progress"),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Overview", tabName = "overview", icon = icon("chart-pie")),
      menuItem("Participant Codes", tabName = "codes", icon = icon("id-card")),
      menuItem("Languages", tabName = "languages", icon = icon("language"))
    )
  ),
  dashboardBody(
    tabItems(
      # ---- Overview ----------------------------------------------------
      tabItem(
        tabName = "overview",
        fluidRow(
          valueBoxOutput("box_pct_complete"),
          valueBoxOutput("box_n_subjects"),
          valueBoxOutput("box_n_languages")
        ),
        fluidRow(
          box(
            title = "Participants by lab", width = 12, status = "primary", solidHeader = TRUE,
            DTOutput("lab_summary_table")
          )
        )
      ),
      # ---- Participant Codes --------------------------------------------
      tabItem(
        tabName = "codes",
        box(
          title = "Participant codes (check yours against this list)",
          width = 12, status = "primary", solidHeader = TRUE,
          helpText(
            "Placeholder data -- this will be sourced from formr once the ",
            "consent form exists (see R/load_data.R's load_consent_codes())."
          ),
          DTOutput("codes_table")
        )
      ),
      # ---- Languages (subtab per language) -------------------------------
      tabItem(
        tabName = "languages",
        do.call(tabBox, c(
          list(width = 12, id = "language_tabs"),
          lapply(all_languages, function(lang) {
            tabPanel(
              title = lang,
              DTOutput(paste0("word_progress_", lang))
            )
          })
        ))
      )
    )
  )
)

server <- function(input, output, session) {
  consent_codes <- load_all_consent_codes(all_languages)
  lab_summary <- summarize_by_lab(consent_codes)
  pct_complete <- overall_completion(active_languages)

  output$box_pct_complete <- renderValueBox({
    valueBox(sprintf("%.1f%%", pct_complete * 100), "Overall percent completed",
             icon = icon("check-circle"), color = "green")
  })
  output$box_n_subjects <- renderValueBox({
    valueBox(nrow(consent_codes), "Number of subjects",
             icon = icon("users"), color = "blue")
  })
  output$box_n_languages <- renderValueBox({
    valueBox(length(active_languages), "Active languages",
             icon = icon("language"), color = "purple")
  })

  output$lab_summary_table <- renderDT({
    datatable(lab_summary, rownames = FALSE, options = list(pageLength = 10))
  })

  output$codes_table <- renderDT({
    display <- consent_codes %>%
      select(timestamp, lab_id, participant_code) %>%
      rename(`Date/Time` = timestamp, `Lab ID` = lab_id, `Code` = participant_code) %>%
      arrange(desc(`Date/Time`))
    datatable(display, rownames = FALSE, filter = "top",
              options = list(pageLength = 25, order = list(list(0, "desc"))))
  })

  for (lang in all_languages) {
    local({
      this_lang <- lang
      output[[paste0("word_progress_", this_lang)]] <- renderDT({
        progress <- load_word_progress(this_lang)
        progress$bar <- mapply(progress_bar_html, progress$pct,
                                sprintf("%d / %d", progress$n_valid, progress$target_n))
        display <- progress %>% select(cue, bar) %>% rename(Word = cue, `Valid responses` = bar)
        datatable(display, rownames = FALSE, escape = FALSE, filter = "top",
                  options = list(pageLength = 25))
      })
    })
  }
}

shinyApp(ui, server)
