# ============================================================
#  Setup
# ============================================================

projDir <- " "
setwd(projDir)

packages <- c("readxl", "psych", "dplyr", "ggplot2", "ggpubr", "tidyr", "BayesFactor", "bayestestR",  
  "mgcv", "npreg", "coin", "effsize", "rstatix", "e1071", "nparLD"      
)
invisible(lapply(packages, library, character.only = TRUE))


# ============================================================
#  Load Data
# ============================================================

beh     <- read_excel("compiled_bhv_results_19MD_21TD_wMathAbility_sept23.xlsx", sheet = "Sheet1")
colnames(beh)[1] <- "Subject"
beh$Visit <- ifelse(beh$time == "pre", 1, 2)
beh.pre  <- subset(beh, time == "pre")
beh.post <- subset(beh, time == "post")

raw_dot <- read.csv("comp_dot_92subj_with_and_without_redos.csv")
raw_num <- read.csv("comp_num_92subj_with_and_without_redos.csv")
colnames(raw_num)[1] <- "Subject"

beh_LT  <- read_excel("SchwartzEtAl_NP_and_Behav.xlsx", sheet = "Sheet1")
LT.AYA  <- subset(beh_LT, Group == "adult")
LT.CH   <- subset(beh_LT, Group == "children")


# ============================================================
#  Load NDE Summary Data & Compute Distance Effect
# ============================================================

dot <- read.csv("beh_summary_compdot_TDMD_prepost.csv")
num <- read.csv("beh_summary_compnum_TDMD_prepost.csv")

dot$dist <- dot$Efficiency_near - dot$Efficiency_far
dot$task  <- "Nonsym"

num$dist <- num$Efficiency_near - num$Efficiency_far
num$task  <- "Sym"

dot_pre  <- subset(dot, Time == "1") # 1 = pre, 2 = post
dot_post <- subset(dot, Time == "2")
num_pre  <- subset(num, Time == "1")
num_post <- subset(num, Time == "2")


# ============================================================
#  Normality Checks
# ============================================================

ggdensity(num_post$Efficiency_all, xlab = "efficiency")
ggdensity(num_post$accuracy_all,   xlab = "accuracy")
ggdensity(num_post$median_RT_all,  xlab = "RT")

shapiro.test(dot_post$accuracy_all)
shapiro.test(dot_post$median_RT_all)
shapiro.test(dot_post$Efficiency_all)
shapiro.test(dot_pre$Efficiency_all)
shapiro.test(dot_post$dist)
shapiro.test(dot_pre$dist)

skewness(dot_pre$median_RT_all)
skewness(dot_pre$accuracy_all)
skewness(dot_pre$Efficiency_all)

shapiro.test(num_post$accuracy_all)
shapiro.test(num_post$median_RT_all)
shapiro.test(num_post$Efficiency_all)
shapiro.test(num_pre$Efficiency_all)
shapiro.test(num_post$dist)
shapiro.test(num_pre$dist)

skewness(num_pre$median_RT_all)
skewness(num_pre$accuracy_all)
skewness(num_pre$Efficiency_all)


# ============================================================
#  STT: Combine & Prepare Long Format
# ============================================================

DF <- rbind(dot, num) %>%
  mutate(
    Time  = as.factor(Time),
    task  = as.factor(task),
    Group = ifelse(Time == "1", "Pre-training", "Post-training"),
    Group = ordered(Group, c("Pre-training", "Post-training")),
    eff_dist = Efficiency_near - Efficiency_far
  )

DF_pre  <- subset(DF, Group == "Pre-training")
DF_post <- subset(DF, Group == "Post-training")

DF %>%
  dplyr::group_by(Time, task) %>%
  dplyr::summarise(
    cor = cor(accuracy_all, median_RT_all),
    p   = cor.test(accuracy_all, median_RT_all)$p.value,
    n   = n(),
    .groups = "drop"
  )


# ============================================================
#  STT: Nonparametric ANOVAs (nparLD)
# ============================================================

anova_eff  <- nparLD(Efficiency_all ~ Group * task, data = DF, subject = "Subject", description = FALSE)
summary(anova_eff)
anova_eff$ANOVA.test.mod.Box

anova_acc  <- nparLD(accuracy_all   ~ Group * task, data = DF, subject = "Subject", description = FALSE)
summary(anova_acc)
plot(anova_acc)

anova_rt   <- nparLD(median_RT_all  ~ Group * task, data = DF, subject = "Subject", description = FALSE)
summary(anova_rt)
plot(anova_rt)

anova_dist <- nparLD(eff_dist       ~ Group * task, data = DF, subject = "Subject", description = FALSE)
summary(anova_dist)
plot(anova_dist)


# ============================================================
#  STT: Wilcoxon & Effect Size (task comparisons)
# ============================================================

for (outcome in c("Efficiency_all", "accuracy_all", "median_RT_all", "eff_dist")) {
  formula <- as.formula(paste(outcome, "~ task"))
  cat("\n---", outcome, "---\n")
  print(DF_pre  %>% wilcox_test(formula))
  print(DF_pre  %>% cliff.delta(formula))
  print(DF_post %>% wilcox_test(formula))
  print(DF_post %>% cliff.delta(formula))
}


# ============================================================
#  STT: Wilcoxon & Effect Size (time comparisons)
# ============================================================

DF_nonsym <- subset(DF, task == "Nonsym")
DF_sym    <- subset(DF, task == "Sym")

for (outcome in c("Efficiency_all", "accuracy_all", "median_RT_all", "eff_dist")) {
  formula <- as.formula(paste(outcome, "~ Group"))
  cat("\n---", outcome, "---\n")
  print(DF_nonsym %>% wilcox_test(formula, paired = TRUE))
  print(DF_nonsym %>% cliff.delta(formula, paired = TRUE))
  print(DF_sym    %>% wilcox_test(formula, paired = TRUE))
  print(DF_sym    %>% cliff.delta(formula, paired = TRUE))
}


# ============================================================
#  STT: Spearman Correlations & GSM (wide format)
# ============================================================

DF_wide <- DF[, c("Subject", "Group", "eff_dist", "Efficiency_all",
                  "accuracy_all", "median_RT_all", "task")] %>%
  pivot_wider(
    id_cols     = c(Subject, Group),
    names_from  = task,
    values_from = c(eff_dist, Efficiency_all, accuracy_all, median_RT_all)
  )

DF_wide_pre  <- subset(DF_wide, Group == "Pre-training")
DF_wide_post <- subset(DF_wide, Group == "Post-training")

for (outcome in c("Efficiency_all", "accuracy_all", "median_RT_all", "eff_dist")) {
  cat("\n--- Pre:", outcome, "---\n")
  print(cor.test(DF_wide_pre[[paste0(outcome, "_Nonsym")]],
                 DF_wide_pre[[paste0(outcome, "_Sym")]], method = "spearman"))
  cat("--- Post:", outcome, "---\n")
  print(cor.test(DF_wide_post[[paste0(outcome, "_Nonsym")]],
                 DF_wide_post[[paste0(outcome, "_Sym")]], method = "spearman"))
}

# Coin distance effect (independent)
coin::wilcox_test(eff_dist ~ Group, paired = TRUE, data = DF_nonsym)
coin::wilcox_test(eff_dist ~ Group, paired = TRUE, data = DF_sym)

# GSM interaction models
summary(gsm(Efficiency_all_Nonsym ~ Efficiency_all_Sym * Group, data = DF_wide))
summary(gsm(accuracy_all_Nonsym   ~ accuracy_all_Sym   * Group, data = DF_wide))
summary(gsm(median_RT_all_Nonsym  ~ median_RT_all_Sym  * Group, data = DF_wide))
summary(gsm(eff_dist_Nonsym       ~ eff_dist_Sym       * Group, data = DF_wide))


# ============================================================
#  LTD: Load & Prepare
# ============================================================

beh_LT_dot <- beh_LT[, c("Subject", "Group", colnames(beh_LT)[8],
                         colnames(beh_LT)[12], colnames(beh_LT)[13], colnames(beh_LT)[14])]
beh_LT_num <- beh_LT[, c("Subject", "Group", colnames(beh_LT)[9],
                         colnames(beh_LT)[16], colnames(beh_LT)[17], colnames(beh_LT)[18])]

colnames(beh_LT_dot) <- c("Subject", "Group", "dist", "rt", "acc", "eff")
colnames(beh_LT_num) <- c("Subject", "Group", "dist", "rt", "acc", "eff")

beh_LT_dot$task <- "Nonsym"
beh_LT_num$task <- "Sym"

LT       <- rbind(beh_LT_dot, beh_LT_num)
LT$task  <- as.factor(LT$task)
LT_ad    <- subset(LT, Group == "adult")
LT_ch    <- subset(LT, Group == "children")
LT_nonsym <- subset(LT, task == "Nonsym")
LT_sym    <- subset(LT, task == "Sym")


# ============================================================
#  LTD: Normality Checks
# ============================================================

for (grp in list(beh_LT_dot[beh_LT_dot$Group == "adult",  ],
                 beh_LT_dot[beh_LT_dot$Group == "children",],
                 beh_LT_num[beh_LT_num$Group == "adult",  ],
                 beh_LT_num[beh_LT_num$Group == "children",])) {
  cat("\nGroup:", grp$Group[1], "| Task:", grp$task[1], "\n")
  print(shapiro.test(grp$eff))
  print(shapiro.test(grp$dist))
}

skewness(beh_LT_num$eff)
shapiro.test(beh_LT_num$dist)


# ============================================================
#  LTD: GSM & Wilcoxon Tests
# ============================================================

summary(gsm(eff  ~ task * Group, data = LT))
summary(gsm(dist ~ task * Group, data = LT))

for (outcome in c("eff", "dist")) {
  formula <- as.formula(paste(outcome, "~ task"))
  cat("\n---", outcome, "---\n")
  print(LT_ad %>% wilcox_test(formula))
  print(LT_ad %>% cliff.delta(formula))
  print(LT_ch %>% wilcox_test(formula))
  print(LT_ch %>% cliff.delta(formula))
  
  formula_grp <- as.formula(paste(outcome, "~ Group"))
  print(LT_nonsym %>% wilcox_test(formula_grp))
  print(LT_nonsym %>% cliff.delta(formula_grp))
  print(LT_sym    %>% wilcox_test(formula_grp))
  print(LT_sym    %>% cliff.delta(formula_grp))
}


# ============================================================
#  LTD: Correlations & GSM (wide format)
# ============================================================

LT_wide    <- LT    %>% pivot_wider(names_from = task, values_from = c(dist, rt, acc, eff))
LT_wide_ch <- LT_ch %>% pivot_wider(names_from = task, values_from = c(dist, rt, acc, eff))
LT_wide_ad <- LT_ad %>% pivot_wider(names_from = task, values_from = c(dist, rt, acc, eff))

for (outcome in c("dist", "eff")) {
  cat("\n--- Children:", outcome, "---\n")
  print(cor.test(LT_wide_ch[[paste0(outcome, "_Nonsym")]], LT_wide_ch[[paste0(outcome, "_Sym")]]))
  print(cor.test(LT_wide_ch[[paste0(outcome, "_Nonsym")]], LT_wide_ch[[paste0(outcome, "_Sym")]], method = "spearman"))
  cat("--- Adults:", outcome, "---\n")
  print(cor.test(LT_wide_ad[[paste0(outcome, "_Nonsym")]], LT_wide_ad[[paste0(outcome, "_Sym")]]))
  print(cor.test(LT_wide_ad[[paste0(outcome, "_Nonsym")]], LT_wide_ad[[paste0(outcome, "_Sym")]], method = "spearman"))
}

correlationBF(LT_wide_ad$dist_Nonsym, LT_wide_ad$dist_Sym)
r.test(n = 52, r12 = 0.788799, n2 = 47, r34 = 0.7686946)

summary(gsm(dist_Nonsym ~ dist_Sym * Group, family = gaussian(), data = LT_wide))
summary(gsm(eff_Nonsym  ~ eff_Sym  * Group, family = gaussian(), data = LT_wide))


# ============================================================
#  STT vs. LTD Comparisons
# ============================================================

DF <- rbind(dot, num) %>%
  mutate(
    Time     = as.factor(Time),
    Group    = ifelse(Time == "1", "Pre-training", "Post-training"),
    eff_dist = Efficiency_near - Efficiency_far
  )

DF_pre  <- subset(DF, Group == "Pre-training")
DF_post <- subset(DF, Group == "Post-training")

ST_pre  <- DF_pre[,  c("Subject", "Group", "eff_dist", "median_RT_all", "accuracy_all", "Efficiency_all", "task")]
ST_post <- DF_post[, c("Subject", "Group", "eff_dist", "median_RT_all", "accuracy_all", "Efficiency_all", "task")]

colnames(ST_pre)  <- c("Subject", "Group", "dist", "rt", "acc", "eff", "task")
colnames(ST_post) <- c("Subject", "Group", "dist", "rt", "acc", "eff", "task")

young <- rbind(ST_pre,  LT_ch) %>% mutate(Group = as.factor(Group))
old   <- rbind(ST_post, LT_ad) %>% mutate(Group = as.factor(Group))

young_nonsym <- subset(young, task == "Nonsym")
young_sym    <- subset(young, task == "Sym")
old_nonsym   <- subset(old,   task == "Nonsym")
old_sym      <- subset(old,   task == "Sym")
preold_sym   <- rbind(ST_pre, LT_ad) %>%
  mutate(Group = as.factor(Group)) %>%
  subset(task == "Sym")

# Efficiency comparisons
coin::wilcox_test(eff ~ Group, paired = FALSE, data = young_nonsym)
young_nonsym %>% cliff.delta(eff ~ Group)
young_sym    %>% wilcox_test(eff ~ Group, paired = FALSE)
young_sym    %>% cliff.delta(eff ~ Group)

coin::wilcox_test(eff ~ Group, paired = FALSE, data = old_nonsym)
old_nonsym %>% cliff.delta(eff ~ Group)
coin::wilcox_test(eff ~ Group, paired = FALSE, data = old_sym)
old_sym    %>% cliff.delta(eff ~ Group)

# Distance comparisons
coin::wilcox_test(dist ~ Group, paired = FALSE, data = young_nonsym)
young_nonsym %>% cliff.delta(dist ~ Group)
young_sym    %>% wilcox_test(dist ~ Group, paired = FALSE)
young_sym    %>% cliff.delta(dist ~ Group)

coin::wilcox_test(dist ~ Group, paired = FALSE, data = preold_sym)
preold_sym %>% cliff.delta(dist ~ Group)
coin::wilcox_test(dist ~ Group, paired = FALSE, data = old_sym)
old_sym    %>% cliff.delta(dist ~ Group)
coin::wilcox_test(dist ~ Group, paired = FALSE, data = old_nonsym)
old_nonsym %>% cliff.delta(dist ~ Group)

# GSM interaction models
ST_pre_wide  <- ST_pre  %>% pivot_wider(names_from = task, values_from = c(dist, rt, acc, eff))
ST_post_wide <- ST_post %>% pivot_wider(names_from = task, values_from = c(dist, rt, acc, eff))

young_wide <- rbind(ST_pre_wide,  LT_wide_ch)
old_wide   <- rbind(ST_post_wide, LT_wide_ad)

summary(gsm(eff_Nonsym  ~ eff_Sym  * Group, family = gaussian(), data = young_wide))
summary(gsm(eff_Nonsym  ~ eff_Sym  * Group, family = gaussian(), data = old_wide))
summary(gsm(dist_Nonsym ~ dist_Sym * Group, family = gaussian(), data = young_wide))
summary(gsm(dist_Nonsym ~ dist_Sym * Group, family = gaussian(), data = old_wide))


# ============================================================
#  Fluency: Normality & Rank Transform
# ============================================================

shapiro.test(beh.pre$fluency)
shapiro.test(beh.post$fluency)
shapiro.test(beh_LT$MathFluency_Std)

hist(beh.pre$fluency)
max(beh$fluency)

beh$fluency_log <- log(140 - beh$fluency)
mean(beh$fluency) - 3 * sd(beh$fluency)

beh.pre$fluency_rank  <- rank(beh.pre$fluency)
beh.post$fluency_rank <- rank(beh.post$fluency)

write.csv(beh.pre,  "STT_beh_pre_rank.csv",  row.names = FALSE)
write.csv(beh.post, "STT_beh_post_rank.csv", row.names = FALSE)