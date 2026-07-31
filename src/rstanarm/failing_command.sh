Rscript /home/rgiordan/Documents/git_repos/CheckBayesIJPaper/BayesIJPaper/src/rstanarm/run_bootstrapped_mcmc_rstanarm.R \
    --base_dir=/home/rgiordan/Documents/git_repos/CheckBayesIJPaper/BayesIJPaper \
    --model_list_ind=2 \
    --save_filename=/home/rgiordan/Documents/git_repos/CheckBayesIJPaper/BayesIJPaper/src/rstanarm/cluster/output/DELETEME_boot_mcmc_0924_cluster.Rdata \
    --default_num_boots=5 \
    --default_num_samples=600 \
    --force


Error in { :
  task 1 failed - "No parameter(s) b[(Intercept) z1_z2:31], b[(Intercept) z1_z2:46], b[(Intercept) z1:14], b[x z1:14], b[(Intercept) z1:23], b[x z1:23], b[(Intercept) z1:4], b[x z1:4]"
Calls: RunRstanarmBootstraps -> %dopar% -> <Anonymous>
