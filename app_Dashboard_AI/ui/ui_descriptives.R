# ui/ui_descriptives.R
library(shiny)
library(bslib)
library(shinyjs)
library(plotly)





descriptivesUI <- tabPanel(
  "Descriptive analyses",
  
  # nécessaire pour le scroll doux via runjs() dans le server
  useShinyjs(),
  
  tabsetPanel(
    id = "desc_tabs",
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
            tags$li(actionLink("goto_ocde_desc_plot1", "Number of AI policies per country")), # lien vers plot 1
            tags$li(actionLink("goto_ocde_desc_plot2", "AI policies map by country")),        # lien vers plot 2
            tags$li(actionLink("goto_ocde_desc_plot3", "AI policies over time"))              # lien vers plot 3
          )
        ),
      
      
        
        # - Contenu principal : chaque section a un id -
        div(
          # Plot 1
          tags$div(
            id = "ocde_desc_plot1",
            h3("Number of AI policies by country"),
            plotlyOutput("nbr_politique_pr_pays", height = "520px")
          ),
          tags$hr(),
          
          # Plot 2
          tags$div(
            id = "ocde_desc_plot2",
            h3("AI policies map by country"),
            plotlyOutput("nbr_pol_carte_pays", height = "600px")
          ),
          tags$hr(),
          
          # Plot 3
          tags$div(
            id = "ocde_desc_plot3",
            h3("AI policies over time"),
            plotlyOutput("nbr_pol_anne", height = "500px")  # <-- correspond bien au server
          )
        )
      )
    )
  )
)
