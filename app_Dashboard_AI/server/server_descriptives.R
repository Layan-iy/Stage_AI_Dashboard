# server/server_descriptives.R
library(dplyr)
library(ggplot2)
library(plotly)
library(shinyjs)

# ---------- Données nettoyées de base ----------
# on utilise l'objet 'oecd' défini dans global.R
df_clean <- oecd %>%
  filter(!is.na(country), country != "", !is.na(policy_initiative_id))

# - PLOT 1 : Top pays (initiatives uniques) -
top_countries_df <- df_clean %>%
  group_by(country) %>%
  summarise(Initiatives = n_distinct(policy_initiative_id), .groups = "drop") %>%
  arrange(desc(Initiatives)) %>%
  slice_head(n = 15)

output$nbr_politique_pr_pays <- renderPlotly({
  p <- ggplot(
    top_countries_df,
    aes(x = reorder(country, Initiatives), y = Initiatives,
        text = paste0("Country: ", country, "<br>Initiatives: ", Initiatives))
  ) +
    geom_col(fill = "#1c9099") +
    coord_flip() +
    labs(
      title = "Top 15 countries by distinct AI policy initiatives (OECD)",
      x = NULL, y = "Number of distinct initiatives"
    ) +
    theme_minimal(base_size = 12) +
    theme(
      axis.text.y = element_text(face = "bold"),
      plot.title  = element_text(face = "bold", hjust = 0.5),
      plot.margin = margin(t = 20, r = 20, b = 20, l = 20)
    )
  
  ggplotly(p, tooltip = "text") %>%
    layout(margin = list(l = 180))
})

# Downloads pour le plot 1
output$download_desc_csv <- downloadHandler(
  filename = function() "oecd_top_countries_distinct_initiatives.csv",
  content  = function(file) {
    readr::write_csv(top_countries_df, file)
  }
)

output$download_bar_png <- downloadHandler(
  filename = function() "oecd_top_countries_bar.png",
  content  = function(file) {
    p <- ggplot(
      top_countries_df,
      aes(x = reorder(country, Initiatives), y = Initiatives)
    ) +
      geom_col(fill = "#1c9099") +
      coord_flip() +
      labs(
        title = "Top 15 countries by distinct AI policy initiatives (OECD)",
        x = NULL, y = "Number of distinct initiatives"
      ) +
      theme_minimal(base_size = 12)
    ggsave(filename = file, plot = p, width = 10, height = 7, dpi = 180)
  }
)

# ========= PLOT 2 : Carte par pays (ISO3) =========
map_df <- df_clean %>%
  group_by(country, iso3) %>%
  summarise(Initiatives = n_distinct(policy_initiative_id), .groups = "drop")

output$nbr_pol_carte_pays <- renderPlotly({
  plot_ly(
    type = "choropleth",
    locations   = map_df$iso3,
    locationmode= "ISO-3",
    z           = map_df$Initiatives,
    text        = map_df$country,
    colorscale  = "Blues",
    colorbar    = list(title = "Initiatives")
  ) %>%
    layout(
      title = list(
        text = "AI policy initiatives by country (OECD)",
        x = 0.5, xanchor = "center", yanchor = "top"
      ),
      geo = list(
        showframe = FALSE,
        showcoastlines = TRUE,
        projection = list(type = 'equirectangular')
      ),
      margin = list(l = 20, r = 20, t = 60, b = 20)
    )
})

# -- PLOT 3 : Nouvelles politiques par année --
oecd_yearly <- oecd %>%
  filter(!is.na(start_date)) %>%
  group_by(start_date) %>%
  summarise(NewInitiatives = n_distinct(policy_initiative_id), .groups = "drop") %>%
  arrange(start_date)

output$nbr_pol_anne <- renderPlotly({
  plot_ly(
    data = oecd_yearly,
    x = ~start_date,
    y = ~NewInitiatives,
    type = "scatter",
    mode = "lines+markers",
    hovertemplate = "Year: %{x}<br>New initiatives: %{y}<extra></extra>"
  ) %>%
    layout(
      title = "New AI policy initiatives per year (OECD)",
      xaxis = list(title = "Year"),
      yaxis = list(title = "Count")
    )
})

# -- Scroll doux --
observeEvent(input$goto_ocde_desc_plot1, {
  runjs("document.getElementById('ocde_desc_plot1').scrollIntoView({behavior:'smooth'});")
})
observeEvent(input$goto_ocde_desc_plot2, {
  runjs("document.getElementById('ocde_desc_plot2').scrollIntoView({behavior:'smooth'});")
})
observeEvent(input$goto_ocde_desc_plot3, {
  runjs("document.getElementById('ocde_desc_plot3').scrollIntoView({behavior:'smooth'});")
})
