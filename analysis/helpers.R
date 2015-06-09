con = dbConnect(dbDriver("PostgreSQL"), dbname = "agency-loan-level")
query = function(sql) { fetch(dbSendQuery(con, sql), n = 1e8) }

w = 640
h = 420

annualize = function(monthly_rate) {
  1 - (1 - monthly_rate) ^ 12
}

add_credits = function() {
  grid.text("toddwschneider.com",
            x = 0.99,
            y = 0.02,
            just = "right",
            gp = gpar(fontsize = 12, col = "#777777"))
}

title_with_subtitle = function(title, subtitle = "") {
  ggtitle(bquote(atop(.(title), atop(.(subtitle)))))
}

theme_tws = function(base_size = 12) {
  bg_color = "#f4f4f4"
  bg_rect = element_rect(fill = bg_color, color = bg_color)

  theme_bw(base_size) +
    theme(plot.background = bg_rect,
          panel.background = bg_rect,
          legend.background = bg_rect,
          panel.grid.major = element_line(colour = "grey80", size = 0.25),
          panel.grid.minor = element_line(colour = "grey90", size = 0.25))
}
