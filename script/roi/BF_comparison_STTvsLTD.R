projDir <- " "
setwd(projDir)

packages <- c(
  "readxl",
  "psych",
  "reshape2",
  "dplyr",
  "BayesFactor",
  "bayestestR",
  "insight",
  "rstanarm"
)

invisible(lapply(packages, library, character.only = TRUE))


################################ data set ###################################

pre =read.table("DevSci_fluency_ch_pre/roi_beta_average.tsv", header = TRUE)
post =read.table("DevSci_fluency_ch_post/roi_beta_average.tsv", header = TRUE)
behav = read.csv("behavioral_data.csv")
LT = read_excel("roi_rsa_fluency_53CH48AD_15ROIs.xlsx") 
colnames(LT)

pre$Group <- "Pre-training"
post$Group <- "Post-training"
pre$Time <- "pre"
post$Time <- "post"

total <- rbind(pre, post)


# cleaning variables
merged <- merge(behav[,c(1,3,6)], total , by=c("Subject","Time"))
colnames(merged)

ST <- merged[,c(1:3,6:21)]

STT <- ST[,c(1,19,3:18)]

LTD <- LT[,c(1,4,5,6:20)]
colnames(LTD)



########### combine  STT & LTD  #########

colnames(STT) <- c("Subject","Group" ,  "fluency", "R preCG","R COper", "R Thalamus","R IPS 42 -44 46","R IPS 30 -52 38","R HIPP","L preMotor","L PreCG",
                   "L Thalamus","L Insula", "L IPS -36 -48 48", "L MFG","L IPS","L IPS/LOC","L HIPP")
colnames(LTD) <- c("Subject", "Group", "fluency",  "L IPS/LOC","L IPS", "L IPS -36 -48 48", "R IPS 30 -52 38", "R IPS 42 -44 46","L HIPP","R HIPP",
                   "L Insula","L MFG","L preMotor","L PreCG","R preCG","L Thalamus","R Thalamus","R COper")

combined <- rbind(STT, LTD)

#######################  correlation differences: bayes factor ################################ 

colnames(combined)  <- c("Subject", "Group","fluency", "R_preCG","R_coper", "R_Thalamus","R_IPS_x42","R_IPS_x30","R_HIPP","L_preMotor","L_PreCG",
                         "L_Thalamus","L_Insula", "L_IPS_x36", "L_MFG","L_IPS_x26","L_IPS_x22","L_HIPP")

combined_L <-combined %>% gather(Regions,NRS,c(4:18))
combined_L$NRS <- as.numeric(combined_L$NRS)
combined_L<- na.omit(combined_L)
#comparison dataset STT Pre vs. Post 
combined_L_STT <- combined_L[combined_L$Group == 'Pre-training'|combined_L$Group == 'Post-training' ,]
#comparison dataset STT Pre vs. LTD children 
combined_L_younger <- combined_L[combined_L$Group == 'Pre-training'|combined_L$Group == 'Children' ,]
#comparison dataset STT Post vs. LTD adolescents 
combined_L_older <- combined_L[combined_L$Group == 'Post-training'|combined_L$Group == 'Adolescents' ,]


roi_list<- colnames(combined[4:18]) 
output <- matrix(ncol=2, nrow=15)
colnames(output) <- c("regions", "b")

run_bf_loop <- function(data, roi_list) {
  output <- data.frame(regions = character(15), b = numeric(15))
  for (i in seq_along(roi_list)) {
    roi <- roi_list[i]
    sub <- subset(data, Regions == roi)
    lmbf_wint <- lmBF(fluency ~ NRS + Group + NRS:Group, data = sub)
    lmbf      <- lmBF(fluency ~ NRS + Group,              data = sub)
    bf_int    <- lmbf_wint / lmbf
    output[i, "regions"] <- roi
    output[i, "b"]       <- extractBF(bf_int, logbf = FALSE)$bf
  }
  return(output)
}

cor.diff.bf.STT        <- run_bf_loop(combined_L_STT,     roi_list)
cor.diff.bf.YoungGroup <- run_bf_loop(combined_L_younger, roi_list)
cor.diff.bf.OlderGroup <- run_bf_loop(combined_L_older,   roi_list)



