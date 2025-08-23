  # app.R
  library(shiny)
  library(shinyjs)
  library(bslib) # AJOUT
  
  source("global.R", local = TRUE)   
  
  # UI FILES
  source("ui/ui_descriptives.R")
  source("ui/ui_exploratoires.R")
  
  # SERVER FILES seront chargés dans server()
  
  ui <- navbarPage(
    title = "AI Dashboard",
    
    # applique le thème "Flatly" (Bootswatch, Bootstrap 5) pour styliser l’interface
    theme = bs_theme(version = 5, bootswatch = "flatly"), # (AJOUT)
    
    id = "main_nav",
    position = "fixed-top",   # navbar fixée en haut
    header = tagList(
    tags$style(HTML("
      body { padding-top: 70px; }
  
      /* Barre fixée à gauche */
      .left-fixed-nav {
        position: fixed; left: 0; top: 80px;
        width: 260px; max-height: calc(100vh - 100px);
        overflow-y: auto; padding: 10px;
        background: #f7f7f7; border-right: 1px solid #e5e5e5;
        z-index: 1029; /* sous la navbar bootstrap */
      }
  
      /* Décaler le contenu principal vers la droite */
      .with-left-nav { margin-left: 280px; }
  
      /* Confort scroll avec navbar fixe */
      .section-block { scroll-margin-top: 90px; }
  
      /* Mobile: nav non-fixée et contenu non décalé */
      @media (max-width: 992px){
        .left-fixed-nav{ position: static; width:auto; max-height:none; border-right: none; }
        .with-left-nav{ margin-left:0; }
      }
    "))
  ),
    
  
    useShinyjs(),
    
    # Onglets
    descriptivesUI,
    exploratoiresUI
    # multiSourcesUI
  )
  
  server <- function(input, output, session) {
    source("server/server_descriptives.R", local = TRUE)
    source("server/server_exploratoires.R", local = TRUE)
    # source("server/server_multi_sources.R", local = TRUE)
  }
  
  shinyApp(ui, server)
