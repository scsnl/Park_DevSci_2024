# ============================================================
#  Setup
# ============================================================

projDir <- " "
setwd(projDir)

packages <- c(
  "readxl", "psych", "reshape2", "dplyr", "ggplot2",  "tidyr", 
  "Matrix",  "BayesFactor", "bayestestR", "insight", "rstanarm"
)
invisible(lapply(packages, library, character.only = TRUE))


# ============================================================
#  Load Data
# ============================================================

pre   <- read.table("DevSci_fluency_ch_pre/roi_beta_average.tsv",  header = TRUE)
post  <- read.table("DevSci_fluency_ch_post/roi_beta_average.tsv", header = TRUE)
behav <- read.csv("behavioral_data.csv")
LT    <- read_excel("SchwartzEtAl_rois_fluency.xlsx")


# ============================================================
#  Prepare Short-Term Training (STT) Data
# ============================================================

pre$Time  <- "pre"
post$Time <- "post"
total     <- rbind(pre, post)

merged <- merge(behav, total, by = c("Subject", "Time"))

ROIs <- merged[, c("Subject", "Time", "fluency", "R IPS", "R HIPP", "L Insula", "L MFG", "L IPS", "L HIPP")]
ROIs$Time <- as.factor(ROIs$Time)

#change the name for statistical testing
colnames(ROIs) <- c("Subject", "Time", "fluency", "R_IPS", "R_HIPP", "L_Insula", "L_MFG", "L_IPS", "L_HIPP")

roi_cols <- c("R_IPS", "R_HIPP", "L_Insula", "L_MFG", "L_IPS", "L_HIPP")

merged_long <- ROIs %>%
  pivot_longer(cols = all_of(roi_cols), names_to = "Regions", values_to = "NRS") %>%
  mutate(
    NRS    = as.numeric(NRS),
    Group  = ifelse(Time == "pre", "Pre-training", "Post-training"),
    Group  = ordered(Group, c("Pre-training", "Post-training")),
    Regions = ordered(Regions, c("L_IPS", "L_Insula", "L_HIPP", "R_IPS", "L_MFG", "R_HIPP"))
  )


# ============================================================
#  STT Correlation Summary
# ============================================================

merged_long %>%
  group_by(Time, Regions) %>%
  summarise(
    COR = cor(NRS, fluency),
    p   = cor.test(NRS, fluency)$p.value,
    n   = n(),
    .groups = "drop"
  )


# ============================================================
#  STT Scatter Plots
# ============================================================

plot_scatter <- function(data, colors, shapes) {
  ggplot(data, aes(x = NRS, y = fluency, color = Group, shape = Group)) +
    facet_wrap(~Regions) +
    geom_point(size = 2) +
    geom_smooth(method = lm, se = FALSE, fullrange = TRUE) +
    scale_color_manual(values = colors) +
    scale_shape_manual(values = shapes) +
    scale_y_continuous(name = "Arithmetic Fluency") +
    scale_x_continuous(name = "Cross-format NRS") +
    theme_classic() +
    theme(
      legend.position  = "top",
      strip.text       = element_text(size = 14, face = "bold"),
      legend.title     = element_text(size = 14),
      legend.text      = element_text(size = 13),
      axis.title.x     = element_text(colour = "Black", size = 15, face = "bold"),
      axis.title.y     = element_text(colour = "Black", size = 15, face = "bold"),
      axis.text.x      = element_text(angle = 0, vjust = 0.5, size = 14),
      axis.text.y      = element_text(angle = 0, vjust = 0.5, size = 14)
    )
}

plot_scatter(merged_long,
             colors = c("dodgerblue", "tomato1"),
             shapes = c(1, 17))


# ============================================================
#  STT Interaction: Bayes Factor (LM)
# ============================================================

lmbf_with    <- lmBF(fluency ~ L_Insula + Time + L_Insula:Time, data = ROIs)
lmbf_without <- lmBF(fluency ~ L_Insula + Time,                 data = ROIs)
lmbf_with / lmbf_without


# ============================================================
#  STT Correlation Difference Tests (r.test)
# ============================================================

# Pre vs. Post correlations (n = 40 each)
r_test_results_STT <- list(
  L_IPS    = r.test(n = 40, r12 =  0.449, n2 = 40, r34 = -0.0308),
  L_Insula = r.test(n = 40, r12 =  0.515, n2 = 40, r34 = -0.171),
  L_HIPP   = r.test(n = 40, r12 =  0.395, n2 = 40, r34 =  0.157),
  R_IPS    = r.test(n = 40, r12 =  0.379, n2 = 40, r34 =  0.186),
  L_MFG    = r.test(n = 40, r12 =  0.531, n2 = 40, r34 =  0.272),
  R_HIPP   = r.test(n = 40, r12 =  0.303, n2 = 40, r34 =  0.132)
)


# ============================================================
#  Prepare Long-Term (LT) Data
# ============================================================

LT_ROIs <- LT[, c("Subject", "Time", "fluency", "R IPS", "R HIPP", "L Insula", "L IPS", "L HIPP", "L MFG")]
colnames(LT_ROIs) <- c("Subject", "Time", "fluency", "R_IPS", "R_HIPP", "L_Insula", "L_IPS", "L_HIPP", "L_MFG")

LT_ROIs_long <- LT_ROIs %>%
  pivot_longer(cols = all_of(roi_cols), names_to = "Regions", values_to = "NRS") %>%
  mutate(NRS = as.numeric(NRS))


# ============================================================
#  Post-training vs. adolescents (LTD)
# ============================================================

post_long <- subset(merged_long, Time == "post")
Time2 <- rbind(
  post_long,
  subset(LT_ROIs_long, Time == "adult")
) %>%
  mutate(
    fluency = as.numeric(fluency),
    NRS     = as.numeric(NRS),
    Group   = ifelse(Time == "post", "Post-training (STT sample)", "AYA (LTD sample)"),
    Group   = ordered(Group, c("Post-training (STT sample)", "AYA (LTD sample)")),
    Regions = ordered(Regions, c("L_IPS", "L_Insula", "L_HIPP", "R_IPS", "L_MFG", "R_HIPP"))
  )

plot_scatter(Time2,
             colors = c("tomato1", "darkorchid1"),
             shapes = c(17, 17))

na.omit(Time2) %>%
  group_by(Time, Regions) %>%
  summarise(
    COR = cor(NRS, fluency),
    p   = cor.test(NRS, fluency)$p.value,
    n   = n(),
    .groups = "drop"
  )

# Post vs. adolescents correlation difference tests
r_test_results_post_adult <- list(
  L_IPS    = r.test(n = 40, r12 =  0.0193, n2 = 48, r34 = -0.0481),
  R_IPS    = r.test(n = 40, r12 =  0.230,  n2 = 48, r34 = -0.0788),
  L_Insula = r.test(n = 40, r12 = -0.135,  n2 = 48, r34 = -0.0384),
  L_MFG    = r.test(n = 40, r12 =  0.322,  n2 = 44, r34 = -0.00407),
  L_HIPP   = r.test(n = 40, r12 =  0.144,  n2 = 48, r34 =  0.0554),
  R_HIPP   = r.test(n = 40, r12 =  0.198,  n2 = 48, r34 =  0.0866)
)


# ============================================================
#  Pre-training vs. Children (LTD)
# ============================================================

pre_long <- subset(merged_long, Time == "pre")
Time1 <- rbind(
  pre_long,
  subset(LT_ROIs_long, Time == "children")
) %>%
  mutate(
    fluency = as.numeric(fluency),
    NRS     = as.numeric(NRS),
    Regions = ordered(Regions, c("L_IPS", "R_IPS", "L_Insula", "L_MFG", "L_HIPP", "R_HIPP"))
  )

Time1 %>%
  group_by(Time, Regions) %>%
  summarise(
    COR = cor(NRS, fluency),
    p   = cor.test(NRS, fluency)$p.value,
    n   = n(),
    .groups = "drop"
  )

# Pre vs. Children correlation difference tests
r_test_results_pre_children <- list(
  L_IPS    = r.test(n = 40, r12 = 0.485, n2 = 53, r34 = 0.385),
  R_IPS    = r.test(n = 40, r12 = 0.378, n2 = 53, r34 = 0.351),
  L_Insula = r.test(n = 40, r12 = 0.543, n2 = 53, r34 = 0.472),
  L_MFG    = r.test(n = 40, r12 = 0.558, n2 = 53, r34 = 0.417),
  L_HIPP   = r.test(n = 40, r12 = 0.352, n2 = 53, r34 = 0.419),
  R_HIPP   = r.test(n = 40, r12 = 0.336, n2 = 53, r34 = 0.355)
)


# ============================================================
#  Bayes Factor: Correlations (STT wide format)
# ============================================================

ROIs_wide <- ROIs %>%
  pivot_wider(
    id_cols    = Subject,
    names_from = Time,
    values_from = all_of(c("fluency", roi_cols))
  )

run_correlation_bf <- function(wide_data, roi_cols) {
  results <- list()
  for (roi in roi_cols) {
    pre_col  <- paste0(roi, "_pre")
    post_col <- paste0(roi, "_post")
    results[[paste0(roi, "_pre")]]  <- correlationBF(wide_data$fluency_pre,  wide_data[[pre_col]])
    results[[paste0(roi, "_post")]] <- correlationBF(wide_data$fluency_post, wide_data[[post_col]])
  }
  return(results)
}

bf_results_STT <- run_correlation_bf(ROIs_wide, roi_cols)


# ============================================================
#  Bayes Factor: Correlations (LT adolescents & children)
# ============================================================

adult_wide <- LT_ROIs_long %>%
  filter(Time == "adult") %>%
  na.omit() %>%
  mutate(NRS = as.numeric(NRS)) %>%
  pivot_wider(id_cols = c(Subject, fluency), names_from = Regions, values_from = NRS)

children_wide <- LT_ROIs_long %>%
  filter(Time == "children") %>%
  mutate(NRS = as.numeric(NRS)) %>%
  pivot_wider(id_cols = c(Subject, fluency), names_from = Regions, values_from = NRS)

pairwise.cor(adult_wide[, c("fluency", roi_cols)],    "adolescents_schwartzEtAl")
pairwise.cor(children_wide[, c("fluency", roi_cols)], "Children_schwartzEtAl")

run_lt_bf <- function(wide_data, roi_cols) {
  lapply(roi_cols, function(roi) correlationBF(wide_data$fluency, wide_data[[roi]]))
}

bf_results_children <- run_lt_bf(children_wide, roi_cols)
bf_results_adolescents   <- run_lt_bf(adult_wide,    roi_cols)


# ============================================================
#  Correlation Difference Function & Export
# ============================================================

r.cor.diff <- function(dataset, roilist, group1, group2) {
  result <- data.frame(Regions = character(nrow(roilist)),
                       z       = numeric(nrow(roilist)),
                       p       = numeric(nrow(roilist)),
                       stringsAsFactors = FALSE)
  
  for (i in seq_len(nrow(roilist))) {
    roi <- roilist$Name[i]
    g1  <- dataset[dataset$Group == group1 & dataset$Regions == roi, ]
    g2  <- dataset[dataset$Group == group2 & dataset$Regions == roi, ]
    
    test <- r.test(n = g1$n, r12 = g1$COR, n2 = g2$n, r34 = g2$COR)
    result[i, ] <- list(roi, test$z, test$p)
  }
  
  return(result)
}

Cor_Math <- rbind(Cor_Math_ST, Cor_Math_LT)

r_diff_pre_children <- r.cor.diff(Cor_Math, roilist, "pre",  "children")
r_diff_post_adult   <- r.cor.diff(Cor_Math, roilist, "post", "adult")
r_diff_ST           <- r.cor.diff(Cor_Math_ST, roilist, "pre", "post")

write.csv(r_diff_ST, "MetaAnalysisROIs_Results/r.corr.diff_Num_ST.csv", row.names = FALSE)
