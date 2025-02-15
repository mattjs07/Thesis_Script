library(dplyr)
library(data.table)
library(beepr)
library(fastDummies)
library(lmtest)
library(multiwayvcov)
library(stargazer)


setwd("C:/Users/matti/Desktop/Thesis/Data/R/Data")

df <- fread("C:/Users/matti/Desktop/Thesis/Data/R/Data/df_new_variables_29_03.csv "); beep()

###INTRO####
g1 <- df %>% group_by(objet1) %>% summarise(m = mean(ouverture1))
g1 <- g1[-4,]
g1$objet1 <- as.factor(g1$objet1)
ggplot(g1, aes(x= objet1, y =m, fill =)) +geom_col(aes(fill = objet1)) + coord_cartesian(ylim = c(0.7,0.77)) + 
  labs( title = "Opening rate First sending", x = "Group", y = "Opening rate") + theme( plot.title = element_text(hjust = 0.5), legend.position = 'none') +
  scale_x_discrete(labels = c("Neutral","Duration","Money"))
############


df <- df %>% mutate(PBD = kpjdxp)
df <- df %>% mutate(SJR = kqcsjp)
df <- df %>% mutate(abs_left = PBD - anciennete, rel_left = (PBD - anciennete)/PBD, rel_anciennete = anciennete / PBD)
df <- df %>%  filter(!is.na(ouverture1))
#first mail sent the 31 january --> 684
df <- df %>%  filter( date == 684)
df <-  df %>%  filter( erreur1 == 0)
# can filter out the wrong mails sent


df<- dummy_columns(df, select_columns = "region", remove_first_dummy = TRUE)
FE_region <- names(df[, region_2:region_28])
FE_region <- FE_region %>% paste(collapse = "+")
region <- names(df[, region_2:region_28])

sub_Neutral <- df %>% filter(Neutral == 1)
sub_Framed <- df %>% filter(Framed == 1)

vars2 <- c("femme", "age", "upper_2nd_edu", "higher_edu", "contrat_moins_12mois", "contrat_moins_3mois",
          "anciennete", "indemnisation", "PBD", "SJR",  "married","foreigner", "tx_chge", "tx_chge_jeunes",
          "proportion_de_ar", "proportion_de_ld", "proportion_de_sortants", "nombre_de", "nombre_de_rct")

vars <- paste(vars2, collapse = "+" )


GLM.clustered <- function(variables, data){
  g <- glm(data = data, paste( "ouverture1 ~", variables, sep = ""), family = binomial(link = "probit"))
  g <- g %>%  coeftest( vcov. = cluster.vcov( g, cluster = data$kcala, stata_fe_model_rank = TRUE))
  return(g)
}

glm_df <-GLM.clustered(variables = paste(vars, FE_region, sep = "+"), data = df)


glm_N <- GLM.clustered(variables = paste(vars, FE_region, sep = "+"), data = sub_Neutral)

glm_F <- GLM.clustered(variables = paste(vars, FE_region, sep = "+"), data = sub_Framed)

glm_dif <- GLM.clustered(variables = paste(vars, FE_region,"Framed", sep = "+"), data = df)

# glm dif shows us, that even when controlling for characteristics, Framed individuals tend to open LESS the mail !

library(stargazer)

stargazer(glm_df, glm_N, glm_F, glm_dif, column.labels = c("df", "Neutral", "Framed", "F - N"), type = "text", omit = region)

varsint <- paste(vars2, collapse = "*Framed +")
varsint <- paste(varsint, "*Framed", sep = "")
varsint

varsintplus <- paste(vars, varsint, FE_region, sep = "+")

glm_dif2 <- GLM.clustered(variables = paste(varsintplus, "Framed", sep ="+"), data = df)
#if we interact the characteristics with Framed, we observe that :

library(broom) #for glance() 
nobs <- lapply(function(x){glance(x)["nobs"] %>%  as.character}, X = list(glm_N, glm_F, glm_df,  glm_dif,glm_dif2)) %>% as.character()


# labs <- c("women", "age", "upper secondary education", "higher education", "last contract < 12 months", "last contract <3 months", "time since entry in unemployment", "Benefits", "PBD", "Daily Reference wage", "married", "foreigner")
# labsX <- paste(labs, "X Framed", sep = " ")
# LABS <- c(labs, "Framed", labsX)

stargazer(glm_N, glm_F, glm_df,  glm_dif,glm_dif2, 
          omit = region,
          column.labels = c("Neutral", "Framed","All",  "All" ,"All"),
          dep.var.labels = c("First mail opening"),
          add.lines = list(c( "Observations",nobs)),
          type = "text",
          header = FALSE)


####### Now looking at subsamples inside framed ######## 

df <- df %>% mutate( Money = ifelse(objet1 == 3, 1, 0), Duration = ifelse(objet1 == 2, 1, 0)) 

glm_dif3 <- GLM.clustered(variables = paste(vars, FE_region, "Framed + Money", sep ="+"), data = df)

glm_dif4 <- GLM.clustered(variables = paste(vars, FE_region, "Framed + Duration", sep ="+"), data = df)

stargazer(glm_dif, glm_dif3, glm_dif4, type = "text", omit = region) # We observe that the entire impact of "Framed" on opening rate is driven by the negative impact of Money

#What want to investigate = are they different from one group to the other ? WHo opens in Neutral vs Money vs Duration 

############################## 
##### MONEY VS DURATION  ##### 
##############################


sub_MD <- df %>%  filter(Money == 1 | Duration == 1)


glm_MD <- GLM.clustered(variables = paste(vars, FE_region, "Money", sep ="+"), data = sub_MD)
 
varsint <- paste(vars2, collapse = "*Money +")
varsint <- paste(varsint, "*Money", sep = "")
varsint
varsintplus <- paste(vars, varsint, FE_region,sep = "+")


glm_MD2 <-  GLM.clustered(variables = paste(varsintplus, "Money", sep ="+"), data = sub_MD)

varsint <- paste(vars3, collapse = "*Duration +")
varsint <- paste(varsint, "*Duration", sep = "")
varsint
varsintplus <- paste(vars3, varsint, FE_region, sep = "+")


glm_MD3 <- GLM.clustered(variables = paste(varsintplus, "Duration", sep ="+"), data = sub_MD)

vars4 <- c("femme", "age", "upper_2nd_edu", "higher_edu", "contrat_moins_12mois", "contrat_moins_3mois",
                     "indemnisation", "SJR",  "married","foreigner", "tx_chge", "tx_chge_jeunes",
                    "proportion_de_ar", "proportion_de_ld", "proportion_de_sortants", "nombre_de", "nombre_de_rct", "rel_anciennete")
  
  
varsint <- paste(vars4, collapse = "*Duration +")
varsint <- paste(varsint, "*Duration", sep = "")
varsint
varsintplus <- paste(vars4, varsint, FE_region, sep = "+")


glm_MD4 <- GLM.clustered(variables = paste(varsintplus, "Duration", sep ="+"), data = sub_MD)


##############################
##### MONEY VS NEUTRAL #######
##############################

sub_MN <- df %>%  filter(Money == 1 | Neutral == 1)


glm_MN <- GLM.clustered(variables = paste(vars, FE_region, "Money", sep ="+"), data = sub_MN)

varsint <- paste(vars2, collapse = "*Money +")
varsint <- paste(varsint, "*Money", sep = "")
varsint
varsintplus <- paste(vars, varsint, FE_region, sep = "+")


glm_MN2 <- GLM.clustered(variables = paste(varsintplus, "Money", sep ="+"), data = sub_MN)


vars3 <- c("femme", "age", "upper_2nd_edu", "higher_edu", "contrat_moins_12mois", "contrat_moins_3mois",
                     "indemnisation", "SJR",  "married","foreigner", "tx_chge", "tx_chge_jeunes",
                    "proportion_de_ar", "proportion_de_ld", "proportion_de_sortants", "nombre_de", "nombre_de_rct", "rel_left")
  
varsint <- paste(vars3, collapse = "*Money +")
varsint <- paste(varsint, "*Money", sep = "")
varsint
varsintplus <- paste(paste(vars3, collapse = "+"), varsint, FE_region, sep = "+")


glm_MN3 <- GLM.clustered(variables = paste(varsintplus, "Money", sep ="+"), data = sub_MN)


varsint <- paste(vars4, collapse = "*Money +")
varsint <- paste(varsint, "*Money", sep = "")
varsint
varsintplus <- paste(vars4, varsint, FE_region, sep = "+")


glm_MN4 <- GLM.clustered(variables = paste(varsintplus, "Money", sep ="+"), data = sub_MN)


### Same result : Higher educ means lower opening in MOney. And, higher anciennete (length in PBD) means lower interest in Money

##############################
##### DURATION VS NEUTRAL #######
##############################


sub_DN <- df %>%  filter(Duration == 1 | Neutral == 1)


glm_DN <- GLM.clustered(variables = paste(vars, FE_region, "Duration",sep ="+"), data = sub_DN)

varsint <- paste(vars2, collapse = "*Duration +")
varsint <- paste(varsint, "*Duration", sep = "")
varsint
varsintplus <- paste(vars, varsint, FE_region, sep = "+")


glm_DN2 <- GLM.clustered(variables = paste(varsintplus, "Duration",sep ="+"), data = sub_DN)


varsint <- paste(vars3, collapse = "*Duration +")
varsint <- paste(varsint, "*Duration", sep = "")
varsint
varsintplus <- paste(vars3, varsint, FE_region, sep = "+")


glm_DN3 <- GLM.clustered(variables = paste(varsintplus, "Duration", sep ="+"), data = sub_DN)

varsint <- paste(vars4, collapse = "*Duration +")
varsint <- paste(varsint, "*Duration", sep = "")
varsint
varsintplus <- paste(vars4, varsint, FE_region, sep = "+")


glm_DN4 <- GLM.clustered(variables = paste(varsintplus, "Duration", sep ="+"), data = sub_DN)



### anciennete has a positive impact on opening rate (10%), anciennete has a positive impact (5%)

stargazer(glm_N, glm_F, glm_df,  glm_dif,glm_dif2, 
          omit = region,
          column.labels = c("Neutral", "Framed","All",  "All" ,"All"),
          dep.var.labels = c("First mail opening"),
          add.lines = list(c( "Observations",nobs)),
          type = "text",
          header = FALSE)
stargazer(glm_MN, glm_DN, type = "text", column.labels = c("Money", "Duration"), omit = region)
stargazer(glm_dif2, glm_MD2, glm_MN2, glm_DN2, type = "text", column.labels = c("N vs F", "M vs D", "M vs N", "D vs N"), header = TRUE, omit = region)
stargazer(glm_MD3, glm_MN3, glm_DN3, type ="text", omit = region )
stargazer(glm_MD4, glm_MN4, glm_DN4, type ="text", omit = region )



#### Looking at subset susceptible to drive results ### 

df <- df %>% mutate(anciennete_sup =  ifelse(anciennete >= mean(anciennete),1,0), anciennete_inf = ifelse(anciennete < mean(anciennete), 1,0), anciennete2 = anciennete^2 )

Anc_inf <- filter(df,anciennete_inf == 1)
Anc_sup <- filter(df,anciennete_sup == 1)


varsint <- paste(vars2, collapse = "*Framed +")
varsint <- paste(varsint, "*Framed", sep = "")
varsint

varsintplus <- paste(vars, varsint, sep = "+")

glm_inf <- glm(data = Anc_inf, paste( "ouverture1 ~", vars,"+Framed", sep = ""), family = binomial(link = "probit"))
glm_inf <- glm_inf %>%  coeftest( vcov. = cluster.vcov( glm_inf, cluster = Anc_inf$kcala, stata_fe_model_rank = TRUE))
glm_inf

glm_sup <- glm(data = Anc_sup, paste( "ouverture1 ~",vars,"+Framed", sep = ""), family = binomial(link = "probit"))
glm_sup <- glm_sup %>%  coeftest( vcov. = cluster.vcov( glm_sup, cluster = Anc_sup$kcala, stata_fe_model_rank = TRUE))
glm_sup












# Could build a fonction that returns a list with list(glm.clustered, P values ), so that I can feed P val to stargazer  







