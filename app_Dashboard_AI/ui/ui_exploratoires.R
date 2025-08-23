# ui/ui_exploratoires.R
library(shiny)
library(bslib)
library(shinyjs)
library(plotly)




exploratoiresUI <- tabPanel(
  "Exploratory analyses",
  
  useShinyjs(),
  

    # ---- Contenu principal : sous-onglets internes ----
    tabsetPanel(
      id = "expl_tabs",
      type = "tabs",
      
      tabPanel(
        title = "OECD",
        layout_sidebar(
          sidebar = sidebar(
            open = "open",        # sidebar ouverte par défaut
            style = "position:fixed;width:22%;",
            
            sticky = TRUE,        # reste visible au scroll
            width  = 280,         # largeur fixe
            h4("Quick navigation"),   # titre de la barre
            tags$ul(                  # liste des liens rapides
              tags$li(actionLink("goto_ocde_exp_plot1", "Top 20 Countries by Policy Thematic Focus")), # lien vers plot 1
              tags$li(actionLink("goto_ocde_exp_plot2", "Evolution of Policy Types Over Time — OECD")),        # lien vers plot 2
              tags$li(actionLink("goto_ocde_exp_plot3", "Trends in Policy Activity by Country Over Time"))              # lien vers plot 3
            )
          ),
        
        # Plot 1
        tags$div(
          id = "ocde_exp_plot1",
          class = "section-block",
          h3("Exploratory analysis — OECD"),
          p("Top 20 Countries by Policy Thematic Focus"),
          plotlyOutput("exploratory_plot1", height = "650px")
        ),
        tags$hr(),
        
        # Plot 2
        tags$div(
          id = "ocde_exp_plot2",
          class = "section-block",
          h3("Evolution of Policy Types Over Time — OECD"),
          selectInput(
            "exp_country",
            "Country (Top 15 most active):",
            choices = NULL,
            multiple = TRUE
          ),
          
          plotlyOutput("exp_evo_types", height = "520px")
        ),
        tags$hr(),
        
        # Plot 3
        tags$div(
          id = "ocde_exp_plot3",
          class = "section-block",
          h3("Trends in Policy Activity by Country Over Time"),
          plotlyOutput("exp_heatmap", height = "550px")
        )
      )
    )
  )
)

