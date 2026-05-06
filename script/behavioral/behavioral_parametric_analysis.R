# ============================================================
#  Setup
# ============================================================

projDir <- " "
setwd(projDir)

packages <- c("readxl", "psych", "dplyr",  "tidyr", "lmerTest", 
              "lme4", "rstatix", "effectsize", "lsr", "BayesFactor", "bayestestR", "insight", "rstanarm")
invisible(lapply(packages, library, character.only = TRUE))


# ============================================================
#  Load Data
# ============================================================

beh <- read_excel("compiled_bhv_results_19MD_21TD_wMathAbility_sept23.xlsx", sheet = "Sheet1")
colnames(beh)[1] <- "Subject"
beh.pre  <- subset(beh, time == "pre")
beh.post <- subset(beh, time == "post")

beh_LT <- read_excel("SchwartzEtAl_NP_and_Behav.xlsx", sheet = "Sheet1")
LT.AYA <- subset(beh_LT, Group == "adolescent")
LT.CH  <- subset(beh_LT, Group == "children")

NPscore     <- read.csv("mathFUN_NP_data.csv")
NPscore.pre <- subset(NPscore, Visit == "1")
df          <- merge(beh.pre, NPscore.pre, by = "Subject")
summary(df$Age..years.)


# ============================================================
#  Load & Prepare NDE Summary Data
# ============================================================

dot <- read.csv("beh_summary_compdot_TDMD_prepost.csv")
num <- read.csv("beh_summary_compnum_TDMD_prepost.csv")

dot$task <- "Nonsym"
num$task <- "Sym"

DF <- rbind(dot, num) %>%
  mutate(
    Group = ifelse(Time == 1, "Pre-training", "Post-training"),
    Group = ordered(Group, c("Pre-training", "Post-training")),
    Time  = ifelse(Time == 1, "pre", "post"),
    Time  = as.factor(Time),
    task  = as.factor(task)
  )

ST_eff <- DF[, c("Subject", "Group", "Efficiency_all", "task", "median_RT_all", "accuracy_all")]
colnames(ST_eff) <- c("subject", "Group", "eff", "format", "rt", "acc")

ST_nonsym <- subset(ST_eff, format == "Nonsym")
ST_sym    <- subset(ST_eff, format == "Sym")

ST_nonsym[ST_nonsym$Group == "Pre-training", ] %>%
  select(acc) %>%
  summarize_all(~ sum(. > 0.95))
hist(ST_nonsym[ST_nonsym$Group == "Pre-training", ]$acc)

ST_sym[ST_sym$Group == "Post-training", ] %>%
  select(acc) %>%
  summarize_all(~ sum(. > 0.95))
hist(ST_sym[ST_sym$Group == "Post-training", ]$acc)


# ============================================================
#  Bar Plot Helper
# ============================================================

bar_plot <- function(data, y_var, y_lab, y_lim, colors = c("dodgerblue1", "tomato1")) {
  data %>%
    dplyr::group_by(Group, task) %>%
    dplyr::summarise(
      Avg = mean(.data[[y_var]], na.rm = TRUE),
      Std = sd(.data[[y_var]], na.rm = TRUE),
      n   = n(),
      .groups = "drop"
    ) %>%
    mutate(Stderr = Std / sqrt(n)) %>%
    ggplot(aes(x = task, y = Avg, group = Group, fill = Group)) +
    geom_bar(stat = "identity", position = position_dodge()) +
    geom_errorbar(aes(ymax = Avg + Stderr, ymin = Avg - Stderr),
                  width = 0.2, position = position_dodge(0.9)) +
    scale_fill_manual(values = colors) +
    scale_y_continuous(name = y_lab) +
    scale_x_discrete(name = "Format") +
    coord_cartesian(ylim = y_lim) +
    theme_classic() +
    theme(
      strip.text   = element_text(size = 14, face = "bold"),
      legend.title = element_text(size = 14),
      legend.text  = element_text(size = 14),
      axis.title.x = element_text(colour = "Black", size = 16, face = "bold"),
      axis.title.y = element_text(colour = "Black", size = 16, face = "bold"),
      axis.text.x  = element_text(angle = 0, vjust = 0.5, size = 16, face = "bold"),
      axis.text.y  = element_text(angle = 0, vjust = 0.5, size = 16, face = "bold")
    )
}

bar_plot(DF, "Efficiency_all", "Efficiency",      c(0.6, 1.3))
bar_plot(DF, "median_RT_all",  "Reaction Times (ms)", c(600, 1200))
bar_plot(DF, "accuracy_all",   "Accuracy",        c(0.6, 1.05))


# ============================================================
#  STT: Repeated-Measures ANOVA & Bayes Factor
# ============================================================

DF$Subject <- as.factor(DF$Subject)

# Efficiency
anova_comp <- anova_test(data = DF, dv = Efficiency_all, wid = Subject,
                         within = c(Time, task), effect.size = "ges")
get_anova_table(anova_comp)

m <- lm(Efficiency_all ~ Time * task + (1 | Subject), data = DF)
eta_squared(m, partial = FALSE)

bf_eff <- anovaBF(Efficiency_all ~ Time * task + Subject,
                  whichRandom = "Subject", data = DF)
bf_eff

# Paired t-tests & BF: pre vs. post by format
t.test(Efficiency_all ~ Time, data = dot, paired = TRUE)
dot %>% cohens_d(Efficiency_all ~ Time, var.equal = TRUE)
t.test(Efficiency_all ~ Time, data = num, paired = TRUE)
num %>% cohens_d(Efficiency_all ~ Time, var.equal = TRUE)

dot.diff <- dot$Efficiency_all[1:40] - dot$Efficiency_all[41:80]
num.diff <- num$Efficiency_all[1:40] - num$Efficiency_all[41:80]
ttestBF(x = dot.diff)
ttestBF(x = num.diff)

# t-tests: Nonsym vs. Sym by time point
DF_pre  <- subset(DF, Group == "Pre-training")
DF_post <- subset(DF, Group == "Post-training")

t.test(Efficiency_all ~ task, data = DF_pre)
DF_pre  %>% cohens_d(Efficiency_all ~ task, var.equal = TRUE)
t.test(Efficiency_all ~ task, data = DF_post, paired = TRUE)
DF_post %>% cohens_d(Efficiency_all ~ task, var.equal = TRUE)

# Accuracy
DF_sym    <- subset(DF, task == "Sym")
DF_nonsym <- subset(DF, task == "Nonsym")

anova_comp_acc <- anova_test(data = DF, dv = accuracy_all, wid = Subject,
                             within = c(Time, task), effect.size = "ges")
get_anova_table(anova_comp_acc)

t.test(accuracy_all ~ Time, data = DF_nonsym)
t.test(accuracy_all ~ Time, data = DF_sym)
t.test(accuracy_all ~ task, data = DF_pre)
t.test(accuracy_all ~ task, data = DF_post)

# Reaction times
anova_comp_rt <- anova_test(data = DF, dv = median_RT_all, wid = Subject,
                            within = c(Time, task), effect.size = "ges")
get_anova_table(anova_comp_rt)

t.test(median_RT_all ~ Time, data = DF_nonsym)
t.test(median_RT_all ~ Time, data = DF_sym)
t.test(median_RT_all ~ task, data = DF_pre)
t.test(median_RT_all ~ task, data = DF_post)


# ============================================================
#  STT: Correlations (wide format)
# ============================================================

DF_wide <- reshape(DF[, c("Subject", "Group", "Efficiency_all", "median_RT_all",
                          "accuracy_all", "task")],
                   idvar   = c("Subject", "Group"),
                   v.names = c("median_RT_all", "accuracy_all", "Efficiency_all"),
                   timevar = "task", direction = "wide")

DF_wide_pre  <- subset(DF_wide, Group == "Pre-training")
DF_wide_post <- subset(DF_wide, Group == "Post-training")

DF %>%
  group_by(Group, task) %>%
  summarise(
    acc = cor(accuracy_all, median_RT_all),
    p   = cor.test(accuracy_all, median_RT_all)$p.value,
    .groups = "drop"
  )

DF_wide %>%
  group_by(Group) %>%
  summarise(
    eff   = cor(Efficiency_all.Nonsym, Efficiency_all.Sym),
    acc   = cor(accuracy_all.Nonsym,   accuracy_all.Sym),
    rt    = cor(median_RT_all.Nonsym,  median_RT_all.Sym),
    p_eff = cor.test(Efficiency_all.Nonsym, Efficiency_all.Sym)$p.value,
    p_acc = cor.test(accuracy_all.Nonsym,   accuracy_all.Sym)$p.value,
    p_rt  = cor.test(median_RT_all.Nonsym,  median_RT_all.Sym)$p.value,
    n     = n(),
    .groups = "drop"
  )

correlationBF(DF_wide_pre$Efficiency_all.Nonsym,  DF_wide_pre$Efficiency_all.Sym)
correlationBF(DF_wide_post$Efficiency_all.Nonsym, DF_wide_post$Efficiency_all.Sym)

r.test(n = 40, r12 =  0.827, n2 = 40, r34 = 0.694)
r.test(n = 40, r12 =  0.196, n2 = 40, r34 = -0.00322)
r.test(n = 40, r12 =  0.914, n2 = 40, r34 = 0.945)

# STT pre wide correlations
ST_eff_pre      <- subset(ST_eff, Group == "Pre-training")
ST_eff_wide_pre <- reshape(ST_eff_pre, idvar = "subject",
                           v.names = c("eff", "rt", "acc"),
                           timevar = "format", direction = "wide")

ST_eff_wide_pre %>%
  summarise(
    eff   = cor(eff.Nonsym, eff.Sym),
    acc   = cor(acc.Nonsym, acc.Sym),
    rt    = cor(rt.Nonsym,  rt.Sym),
    p_eff = cor.test(eff.Nonsym, eff.Sym)$p.value,
    p_acc = cor.test(acc.Nonsym, acc.Sym)$p.value,
    p_rt  = cor.test(rt.Nonsym,  rt.Sym)$p.value,
    n     = n()
  )



# ============================================================
#  LTD: Efficiency by Format
# ============================================================

beh_LT_dot <- beh_LT[, c(1, 2, 14, 12, 13)]
beh_LT_num <- beh_LT[, c(1, 2, 18, 16, 17)]
colnames(beh_LT_dot) <- c("subject", "Group", "eff", "rt", "acc")
colnames(beh_LT_num) <- c("subject", "Group", "eff", "rt", "acc")
beh_LT_dot$format <- "Nonsym"
beh_LT_num$format <- "Sym"

for (dat in list(beh_LT_dot, beh_LT_num)) {
  print(t.test(eff ~ Group, data = dat))
  print(cohensD(eff ~ Group, data = dat))
  print(ttestBF(formula = eff ~ Group, data = dat))
}

LT_eff         <- rbind(beh_LT_dot, beh_LT_num)
LT_eff$format  <- as.factor(LT_eff$format)
LT_eff$Group   <- as.factor(LT_eff$Group)
LT_eff$subject <- as.factor(LT_eff$subject)

anova_LT_eff <- anova_test(data = LT_eff, dv = eff, wid = subject,
                           effect.size = "ges", between = Group, within = format)
get_anova_table(anova_LT_eff)

bf_LT_eff <- anovaBF(eff ~ Group * format + subject, data = LT_eff, whichRandom = "subject")
bf_LT_eff


# ============================================================
#  STT + LTD: Combined Efficiency Comparisons
# ============================================================

beh_LT_dot2 <- beh_LT[, c(1, 2, 14, 12, 13)]
beh_LT_num2 <- beh_LT[, c(1, 2, 18, 16, 17)]
colnames(beh_LT_dot2) <- c("subject", "Group", "eff_dot", "rt", "acc")
colnames(beh_LT_num2) <- c("subject", "Group", "eff_num", "rt", "acc")

LT_eff2 <- cbind(beh_LT_dot2[, c(1:3)], eff_num = beh_LT_num2[, 3])

LT_eff2 %>%
  group_by(Group) %>%
  summarise(
    acc = cor(eff_dot, eff_num),
    p   = cor.test(eff_dot, eff_num)$p.value,
    .groups = "drop"
  )

r.test(n = 40, r12 = 0.827, n2 = 40, r34 = 0.769)
r.test(n = 40, r12 = 0.694, n2 = 40, r34 = 0.789)

LT_eff_ch <- subset(LT_eff2, Group == "children")
LT_eff_ad <- subset(LT_eff2, Group == "adolescent")

correlationBF(LT_eff_ch$eff_dot, LT_eff_ch$eff_num)
correlationBF(LT_eff_ad$eff_dot, LT_eff_ad$eff_num)

eff <- rbind(LT_eff, ST_eff)
eff$Group <- ordered(eff$Group, c("Pre-training", "children", "Post-training", "adolescent"))

eff_T1 <- subset(eff, Group %in% c("children", "Pre-training"))
eff_T2 <- subset(eff, Group %in% c("adolescent","Post-training"))

eff_T1$Group <- droplevels(eff_T1$Group)
eff_T2$Group <- droplevels(eff_T2$Group)

eff_T1_sym    <- subset(eff_T1, format == "Sym")
eff_T1_nonsym <- subset(eff_T1, format == "Nonsym")
eff_T2_sym    <- subset(eff_T2, format == "Sym")
eff_T2_nonsym <- subset(eff_T2, format == "Nonsym")

eff_T2_sym$Group    <- as.factor(eff_T2_sym$Group)
eff_T2_nonsym$Group <- as.factor(eff_T2_nonsym$Group)

# T1 t-tests
t.test(eff ~ Group, data = eff_T1_sym)
t.test(eff ~ Group, data = eff_T1_nonsym)
t.test(acc ~ Group, data = eff_T1_sym)
t.test(acc ~ Group, data = eff_T1_nonsym)
t.test(rt  ~ Group, data = eff_T1_sym)
t.test(rt  ~ Group, data = eff_T1_nonsym)
ttestBF(formula = eff ~ Group, data = eff_T1_sym)

# T2 t-tests
t.test(eff ~ Group, data = eff_T2_sym)
t.test(acc ~ Group, data = eff_T2_sym)
t.test(rt  ~ Group, data = eff_T2_sym)
cohensD(eff ~ Group, data = eff_T2_sym)
ttestBF(formula = eff ~ Group, data = eff_T2_sym)

t.test(eff ~ Group, data = eff_T2_nonsym)
t.test(acc ~ Group, data = eff_T2_nonsym)
t.test(rt  ~ Group, data = eff_T2_nonsym)
eff_T2_nonsym %>% cohens_d(eff ~ Group)
ttestBF(formula = eff ~ Group, data = eff_T2_nonsym)


# Format comparisons within groups
for (grp_dat in list(
  list(d = subset(eff, Group == "children"),  label = "children"),
  list(d = subset(eff, Group == "adolescent"),  label = "adolescent"),
  list(d = subset(eff, Group == "Pre-training"),  label = "pre"),
  list(d = subset(eff, Group == "Post-training"), label = "post")
)) {
  cat("\n---", grp_dat$label, "---\n")
  print(t.test(eff ~ format, data = grp_dat$d))
  print(t.test(acc ~ format, data = grp_dat$d))
  print(t.test(rt  ~ format, data = grp_dat$d))
}


# ============================================================
#  Distance Effect: STT
# ============================================================

DF$eff_dist  <- DF$Efficiency_near - DF$Efficiency_far
dot$eff_dist <- dot$Efficiency_near - dot$Efficiency_far
num$eff_dist <- num$Efficiency_near - num$Efficiency_far

DF_pre  <- subset(DF, Group == "Pre-training")
DF_post <- subset(DF, Group == "Post-training")

bar_plot(DF, "eff_dist", "Distance Effect", c(0.1, 0.5))

DF$Time <- as.factor(DF$Time)
DF$task <- as.factor(DF$task)

anova_dist <- anova_test(data = DF, dv = eff_dist, wid = Subject,
                         within = c(Time, task))
get_anova_table(anova_dist)

bf_dist <- anovaBF(eff_dist ~ Time * task + Subject, data = DF, whichRandom = "Subject")
bf_dist

ttestBF(formula = eff_dist ~ Time, data = dot)
ttestBF(formula = eff_dist ~ Time, data = num)

t.test(eff_dist ~ Time, data = dot, paired = TRUE)
dot %>% cohens_d(eff_dist ~ Time, var.equal = TRUE)
t.test(eff_dist ~ Time, data = num, paired = TRUE)
num %>% cohens_d(eff_dist ~ Time, var.equal = TRUE)

t.test(eff_dist ~ task, data = DF_pre)
DF_pre %>% cohens_d(eff_dist ~ task, var.equal = TRUE)
ttestBF(formula = eff_dist ~ task, data = DF_pre)

t.test(eff_dist ~ task, data = DF_post)
DF_post %>% cohens_d(eff_dist ~ task, var.equal = TRUE)
ttestBF(formula = eff_dist ~ task, data = DF_post)

mean(num$eff_dist[1:40])
mean(dot$eff_dist[1:40])


# ============================================================
#  Distance Effect: LTD
# ============================================================

dist_LT_dot <- beh_LT[, c(1, 2, 8)]
dist_LT_num <- beh_LT[, c(1, 2, 9)]
colnames(dist_LT_dot) <- c("subject", "Group", "dist")
colnames(dist_LT_num) <- c("subject", "Group", "dist")
dist_LT_dot$format <- "Nonsym"
dist_LT_num$format <- "Sym"

for (dat in list(dist_LT_dot, dist_LT_num)) {
  print(t.test(dist ~ Group, data = dat))
  print(cohensD(dist ~ Group, data = dat))
  print(ttestBF(formula = dist ~ Group, data = dat))
}

LT_dist         <- rbind(dist_LT_dot, dist_LT_num)
LT_dist$format  <- as.factor(LT_dist$format)
LT_dist$Group   <- as.factor(LT_dist$Group)
LT_dist$subject <- as.factor(LT_dist$subject)

anova_LT_dist <- anova_test(data = LT_dist, dv = dist, wid = subject,
                            effect.size = "ges", between = Group, within = format)
get_anova_table(anova_LT_dist)

bf_LT_dist <- anovaBF(dist ~ Group * format + subject, data = LT_dist, whichRandom = "subject")
bf_LT_dist


# ============================================================
#  Distance Effect: STT + LTD Combined
# ============================================================

dist_LT_dot2 <- beh_LT[, c(1, 2, 14, 8)]
dist_LT_num2 <- beh_LT[, c(1, 2, 18, 9)]
colnames(dist_LT_dot2) <- c("subject", "Group", "eff", "dist")
colnames(dist_LT_num2) <- c("subject", "Group", "eff", "dist")
dist_LT_dot2$format <- "Nonsym"
dist_LT_num2$format <- "Sym"

LT_dist2 <- rbind(dist_LT_dot2, dist_LT_num2) %>%
  mutate(format = as.factor(format), Group = as.factor(Group))

dist_ST <- DF[, c("Subject", "Group", "Efficiency_all", "eff_dist", "task")]
colnames(dist_ST) <- c("subject", "Group", "eff", "dist", "format")

ST_wide <- dist_ST  %>% pivot_wider(names_from = format, values_from = c("eff", "dist"))
LT_wide <- LT_dist2 %>% pivot_wider(names_from = format, values_from = c("eff", "dist"))

dist_wide <- rbind(LT_wide, ST_wide)

dist_T1 <- subset(dist_wide, Group %in% c("children",  "Pre-training"))
dist_T2 <- subset(dist_wide, Group %in% c("adolescent",     "Post-training"))

dist_T1$Group <- droplevels(dist_T1$Group)
dist_T2$Group <- droplevels(dist_T2$Group)

BF     <- lmBF(dist_Sym ~ dist_Nonsym + Group,                    data = dist_T1)
BF_Int <- lmBF(dist_Sym ~ dist_Nonsym + Group + dist_Nonsym*Group, data = dist_T1)
BF_Int / BF

r.test(n = 40, r12 = 0.424,  n2 = 53, r34 = 0.376)$p
r.test(n = 40, r12 = 0.261,  n2 = 48, r34 = 0.162)$p
r.test(n = 40, r12 = 0.827,  n2 = 53, r34 = 0.769)$p
r.test(n = 40, r12 = 0.694,  n2 = 48, r34 = 0.789)$p


# ============================================================
#  Distance Effect: Correlation (STT wide)
# ============================================================

DF_wide_dist <- reshape(DF[, c("Subject", "Time", "task", "eff_dist")],
                        idvar   = c("Subject", "Time"),
                        v.names = "eff_dist",
                        timevar = "task", direction = "wide")

DF_wide_dist_pre  <- subset(DF_wide_dist, Time == "pre")
DF_wide_dist_post <- subset(DF_wide_dist, Time == "post")

Cor_lmer <- lmer(eff_dist.Sym ~ eff_dist.Nonsym * Time + (1 | Subject), data = DF_wide_dist)
summary(Cor_lmer)

BF_dist     <- lmBF(eff_dist.Sym ~ eff_dist.Nonsym + Time, data = DF_wide_dist)
BF_dist_Int <- lmBF(eff_dist.Sym ~ eff_dist.Nonsym + Time + eff_dist.Nonsym:Time, data = DF_wide_dist)
BF_dist_Int / BF_dist

DF_wide_dist %>%
  group_by(Time) %>%
  summarise(
    COR = cor(eff_dist.Nonsym, eff_dist.Sym),
    p   = cor.test(eff_dist.Nonsym, eff_dist.Sym)$p.value,
    .groups = "drop"
  )

correlationBF(DF_wide_dist_pre$eff_dist.Nonsym,  DF_wide_dist_pre$eff_dist.Sym)
correlationBF(DF_wide_dist_post$eff_dist.Nonsym, DF_wide_dist_post$eff_dist.Sym)

# ============================================================
#  Distance Effect: LTD Correlations
# ============================================================

distbyformat <- dist_wide %>%
  group_by(Group) %>%
  summarise(
    COR    = cor(dist_Nonsym, dist_Sym, use = "complete.obs"),
    p      = cor.test(dist_Nonsym, dist_Sym)$p.value,
    length = sum(!is.na(dist_Nonsym)),
    .groups = "drop"
  )
print(distbyformat)

distbyformat_ch  <- subset(dist_wide, Group == "children")
distbyformat_aya <- subset(dist_wide, Group == "adolescent")

correlationBF(distbyformat_ch$dist_Nonsym,  distbyformat_ch$dist_Sym)
correlationBF(distbyformat_aya$dist_Nonsym, distbyformat_aya$dist_Sym)

r.test(n = 48, r12 = 0.162, n2 = 40, r34 = 0.424)
r.test(n = 53, r12 = 0.376, n2 = 40, r34 = 0.424)
r.test(n = 48, r12 = 0.162, n2 = 40, r34 = 0.262)

r.test(n = 40, r12 = 0.424, n2 = 40, r34 = 0.261)
r.test(n = 40, r12 = 0.827, n2 = 53, r34 = 0.769)
r.test(n = 40, r12 = 0.694, n2 = 48, r34 = 0.789)
