# =============================================================================
# Predicting and Identifying Biomarkers Associated with Breast Cancer Status:
# A Penalized Logistic Regression Approach
#
# Course project, STAT 6040, Western Michigan University (2026)
#
# Place breast-cancer.csv (not included in this repository) in the same folder
# as this script and set that folder as the working directory. Figures are
# saved to a figures/ folder created there.
#
# Required packages: glmnet, pROC, corrplot
#   install.packages(c("glmnet", "pROC", "corrplot"))
# =============================================================================

library(glmnet)    # LASSO and ridge logistic regression
library(pROC)      # ROC curves and AUC
library(corrplot)  # Correlation plot

breast_cancer <- read.csv("breast-cancer.csv")
dir.create("figures", showWarnings = FALSE)

# -----------------------------------------------------------------------------
# 1. Data preparation
# -----------------------------------------------------------------------------
dim(breast_cancer)
str(breast_cancer)
summary(breast_cancer)

# Outcome: Classification (1 = breast cancer, 0 = no breast cancer)
breast_cancer$Classification <- as.factor(breast_cancer$Classification)
levels(breast_cancer$Classification)

breast_cancer$BC <- factor(ifelse(breast_cancer$Classification == 1, "Yes", "No"),
                           levels = c("No", "Yes"))
table(breast_cancer$BC)

predictors <- c("Age", "BMI", "HOMA", "Leptin", "Adiponectin", "Resistin", "MCP.1")

# -----------------------------------------------------------------------------
# 2. Exploratory data analysis
# -----------------------------------------------------------------------------

# Summary statistics of the predictors (Table 1)
summary(breast_cancer[, predictors])

# Correlation matrix of the predictors (Figure 1)
cor_matrix <- cor(breast_cancer[, predictors], use = "complete.obs")
print(round(cor_matrix, 3))

png("figures/01_correlation_matrix.png", width = 750, height = 512)
corrplot(cor_matrix, method = "color", type = "full",
         tl.cex = 0.8, addCoef.col = "black", number.cex = 0.7)
dev.off()

# -----------------------------------------------------------------------------
# 3. Penalized logistic regression
# -----------------------------------------------------------------------------

# Outcome (factor: "No" is the reference, "Yes" is modeled) and predictor matrix
y <- breast_cancer$BC
x <- model.matrix(BC ~ Age + BMI + HOMA + Leptin + Adiponectin + Resistin + MCP.1,
                  data = breast_cancer)[, -1]

# --- LASSO (alpha = 1), penalty chosen by 10-fold cross-validation ---
set.seed(123)
lasso_cv <- cv.glmnet(x, y, family = "binomial", alpha = 1, nfolds = 10)
lasso_cv$lambda.min

lasso_fit <- glmnet(x, y, family = "binomial", alpha = 1,
                    lambda = lasso_cv$lambda.min)

# Coefficients and odds ratios (Table 2)
coef(lasso_fit)
exp(coef(lasso_fit))

# LASSO coefficient paths (Figure 2)
png("figures/02_lasso_coefficient_paths.png", width = 750, height = 512)
plot(lasso_cv$glmnet.fit, xvar = "lambda", label = TRUE)
title("LASSO Coefficient Paths")
dev.off()

# --- Ridge (alpha = 0), penalty chosen by 10-fold cross-validation ---
set.seed(123)
ridge_cv <- cv.glmnet(x, y, family = "binomial", alpha = 0, nfolds = 10)
ridge_cv$lambda.min

ridge_fit <- glmnet(x, y, family = "binomial", alpha = 0,
                    lambda = ridge_cv$lambda.min)
coef(ridge_fit)

# Ridge coefficient paths
png("figures/04_ridge_coefficient_paths.png", width = 750, height = 512)
plot(ridge_cv$glmnet.fit, xvar = "lambda", label = TRUE)
title("Ridge Coefficient Paths")
dev.off()

# -----------------------------------------------------------------------------
# 4. Model performance
# -----------------------------------------------------------------------------

# Predicted probabilities
lasso_prob <- as.numeric(predict(lasso_fit, newx = x, type = "response"))
ridge_prob <- as.numeric(predict(ridge_fit, newx = x, type = "response"))

# ROC curves and AUC (Figure 3)
roc_lasso <- roc(y, lasso_prob)
roc_ridge <- roc(y, ridge_prob)
auc(roc_lasso)
auc(roc_ridge)

png("figures/03_roc_lasso_vs_ridge.png", width = 750, height = 512)
plot(roc_lasso, col = "red", lwd = 2, main = "ROC: LASSO vs Ridge")
lines(roc_ridge, col = "blue", lwd = 2)
legend("bottomright", legend = c("LASSO", "Ridge"),
       col = c("red", "blue"), lwd = 2)
dev.off()

# Classification accuracy at a 0.5 probability cutoff
lasso_class <- ifelse(lasso_prob > 0.5, "Yes", "No")
ridge_class <- ifelse(ridge_prob > 0.5, "Yes", "No")
mean(lasso_class == y)
mean(ridge_class == y)
