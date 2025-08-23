# server/server_exploratoires.R
library(dplyr)
library(plotly)
library(shinyjs)
library(tidyr)

# - Top 20 pays (par nb d’initiatives DISTINCTES) -
top20_df <- oecd %>%
  group_by(country) %>%
  summarise(total_n = n_distinct(policy_initiative_id), .groups = "drop") %>%
  arrange(desc(total_n)) %>%
  slice_head(n = 20)

top20_countries <- top20_df$country  # ordre décroissant

# ---- Répartition par catégorie + proportions pour ces pays ----
exp_theme_country <- oecd %>%
  filter(country %in% top20_countries,
         !is.na(policy_instrument_type_category),
         policy_instrument_type_category != "") %>%
  count(country, policy_instrument_type_category, name = "n") %>%
  group_by(country) %>%
  mutate(prop = n / sum(n)) %>%
  ungroup()

# ---- Graphe empilé (100% proportions) + infobulle fiable via %{text} ----
output$exploratory_plot1 <- renderPlotly({
  validate(
    need(nrow(exp_theme_country) > 0, "Aucune donnée disponible pour le Top 20 (vérifie policy_instrument_type_category).")
  )
  
  plot_ly(
    data  = exp_theme_country,
    x     = ~prop,
    y     = ~factor(country, levels = rev(top20_countries)),  # top en haut
    color = ~policy_instrument_type_category,
    type  = "bar",
    orientation  = "h",
    # On construit le texte de l’infobulle :
    text = ~paste0(
      "Pays: ", country,
      "<br>Catégorie: ", policy_instrument_type_category,
      "<br>Part: ", round(prop * 100, 1), "%"
    ),
    textposition  = "inside",
    # Utiliser %{text} pour afficher l’infobulle correctement
    hovertemplate = "%{text}<extra></extra>"
    # (alternative: hoverinfo = "text")
  ) %>%
    layout(
      barmode = "stack",
      title   = "Spécialisation thématique par pays (Top 20 — OECD)",
      xaxis   = list(title = "Proportion des types de politiques", tickformat = "%"),
      yaxis   = list(title = "Pays"),
      legend  = list(title = list(text = "Catégorie de politique")),
      margin  = list(l = 160, r = 20, t = 60, b = 40)
    )
})

# (INCHANGÉ)
exp_top15_df <- oecd %>%
  group_by(country) %>%
  summarise(total_n = n_distinct(policy_initiative_id), .groups = "drop") %>%
  arrange(desc(total_n)) %>%
  slice_head(n = 15)

exp_top15_countries <- exp_top15_df$country

# ---- Remplir le selectInput dynamiquement ----
# (INCHANGÉ) - updateSelectInput fonctionne aussi pour les sélections multiples
observe({
  updateSelectInput(
    session, "exp_country",
    choices  = exp_top15_countries,
    selected = exp_top15_countries[1] # Le premier pays est sélectionné par défaut
  )
})

# ---- Données réactives : comptes + proportions par année & catégorie ----
exp_country_stacked <- reactive({
  # On s'assure qu'au moins un pays est sélectionné
  req(input$exp_country)
  
  oecd %>%
    # (MODIFIÉ) On filtre pour inclure TOUS les pays sélectionnés
    filter(
      country %in% input$exp_country,
      !is.na(start_date),
      !is.na(policy_instrument_type_category),
      policy_instrument_type_category != ""
    ) %>%
    # (INCHANGÉ) Le groupement suivant va maintenant agréger les données
    # de tous les pays sélectionnés, ce qui correspond à la "sommation".
    group_by(start_date, policy_instrument_type_category) %>%
    summarise(n = n_distinct(policy_initiative_id), .groups = "drop") %>%
    group_by(start_date) %>%
    mutate(prop = n / sum(n)) %>%
    ungroup() %>%
    arrange(start_date, policy_instrument_type_category)
})

# ---- Barres empilées 100% : y = proportion ; infobulle : nombre + pourcentage ----
output$exp_evo_types <- renderPlotly({
  dat <- exp_country_stacked()
  validate(need(nrow(dat) > 0, "Aucune donnée pour les pays / la période sélectionnés."))
  
  # (AJOUT) Création d'un titre dynamique
  title_text <- if (length(input$exp_country) > 1) {
    "Evolution of Policy Types — Combined total for selected countries"
  } else {
    paste0("Evolution of Policy Types — ", input$exp_country)
  }
  
  plot_ly(
    data  = dat,
    x     = ~start_date,
    y     = ~prop,
    color = ~policy_instrument_type_category,
    type  = "bar",
    customdata = ~n,
    hovertemplate = paste0(
      "Year: %{x}<br>",
      "Initiatives: %{customdata}<br>",
      "Part: %{y:.1%}<extra></extra>"
    )
  ) %>%
    layout(
      barmode = "stack",
      # (MODIFIÉ) On utilise le titre dynamique
      title   = title_text,
      xaxis   = list(title = "Année", dtick = 1),
      yaxis   = list(title = "Part par catégorie", tickformat = "%", rangemode = "tozero"),
      legend  = list(title = list(text = "Catégorie")),
      margin  = list(l = 70, r = 20, t = 60, b = 50)
    )
})

# PLOT 3 - publication temporelle de politique par pays 
# HEATMAP : Activité politique par pays et par année (Top 15)

output$exp_heatmap <- renderPlotly({
  # 1) Sécurité : s'assurer que 'oecd' existe et contient des lignes
  if (!exists("oecd")) return(NULL)
  validate(need(nrow(oecd) > 0, "Dataset 'oecd' vide ou non chargé."))
  
  # 2) Filtre minimal (on garde les années valides)
  df <- oecd %>%
    filter(!is.na(start_date), !is.na(country), country != "",
           !is.na(policy_initiative_id), policy_initiative_id != "")
  
  validate(need(nrow(df) > 0, "Aucune ligne exploitable (start_date/country/id manquants)."))
  
  # 3) Top 15 pays par initiatives DISTINCTES
  hm_top15 <- df %>%
    group_by(country) %>%
    summarise(total_n = n_distinct(policy_initiative_id), .groups = "drop") %>%
    arrange(desc(total_n)) %>%
    slice_head(n = 15) %>%
    pull(country)
  
  validate(need(length(hm_top15) > 0, "Top 15 introuvable (données insuffisantes)."))
  
  # 4) Comptes par (pays, année)
  hm_counts <- df %>%
    filter(country %in% hm_top15) %>%
    group_by(country, start_date) %>%
    summarise(n = n_distinct(policy_initiative_id), .groups = "drop")
  
  validate(need(nrow(hm_counts) > 0, "Pas d'activité sur les pays du Top 15."))
  
  # 5) Années effectivement utilisées (au moins une politique tous pays confondus)
  years_used <- hm_counts %>%
    group_by(start_date) %>%
    summarise(tot = sum(n), .groups = "drop") %>%
    filter(tot > 0) %>%
    arrange(start_date) %>%
    pull(start_date)
  
  if (length(years_used) == 0) return(NULL)
  
  # 6) Grille complète (Top15 × années utilisées) — n = 0 si absence
  hm_grid <- hm_counts %>%
    complete(
      country    = factor(hm_top15, levels = hm_top15),
      start_date = years_used,
      fill = list(n = 0)
    ) %>%
    arrange(country, start_date)
  
  # 7) Heatmap
  plot_ly(
    data = hm_grid,
    x    = ~start_date,
    y    = ~factor(as.character(country), levels = rev(hm_top15)),  # top en haut
    z    = ~n,
    type = "heatmap",
    colorbar = list(title = "New policies"),
    text = ~paste0("Country : ", country,
                   "<br>Year : ", start_date,
                   "<br>Number : ", n),
    hovertemplate = "%{text}<extra></extra>"
  ) %>%
    layout(
      title  = "Heatmap — AI Policy Activity (Top 15 Countries)",
      xaxis  = list(title = "Année", dtick = 1),
      yaxis  = list(title = "Pays"),
      margin = list(l = 120, r = 40, t = 60, b = 60)
    )
})


# Hyperliens de la barre de navigation
observeEvent(input$goto_ocde_exp_plot1, {
  runjs("document.getElementById('ocde_exp_plot1').scrollIntoView({behavior:'smooth'});")
})
observeEvent(input$goto_ocde_exp_plot2, {
  runjs("document.getElementById('ocde_exp_plot2').scrollIntoView({behavior:'smooth'});")
})
observeEvent(input$goto_ocde_exp_plot3, {
  runjs("document.getElementById('ocde_exp_plot3').scrollIntoView({behavior:'smooth'});")
})

