library("dplyr")

targets <- c(
  # 1st calibration set (all independant)
  cc.dx.B = 0.804,
  cc.dx.H = 0.799,
  cc.dx.W = 0.88,
  cc.linked1m.B = 0.62,
  cc.linked1m.H = 0.65,
  cc.linked1m.W = 0.76,
  # CombPrev appendix 8.2.2
  # 2nd calibration set (all independant)
  cc.vsupp.B = 0.55,
  cc.vsupp.H = 0.60,
  cc.vsupp.W = 0.72,
  # STIs
  ir100.gc = 12.81,
  ir100.ct = 14.59,
  # 3rd calibration set
  i.prev.dx.B = 0.33,
  i.prev.dx.H = 0.127,
  i.prev.dx.W = 0.084,
  prep_prop = 0.15
)

# function to calculate the target
mutate_targets <- function(d) {
  d %>% mutate(
    cc.dx.B       = i_dx___B / i___B,
    cc.dx.H       = i_dx___H / i___H,
    cc.dx.W       = i_dx___W / i___W,
    cc.linked1m.B = linked1m___B / i_dx___B,
    cc.linked1m.H = linked1m___H / i_dx___H,
    cc.linked1m.W = linked1m___W / i_dx___W,
    cc.vsupp.B    = i_sup___B / i_dx___B,
    cc.vsupp.H    = i_sup___H / i_dx___H,
    cc.vsupp.W    = i_sup___W / i_dx___W,
    gc_s          = gc_s___B + gc_s___H + gc_s___W,
    ir100.gc      = incid.gc / gc_s * 5200,
    ct_s          = ct_s___B + ct_s___H + ct_s___W,
    ir100.ct      = incid.ct / ct_s * 5200,
    i.prev.dx.B   = i_dx___B / n___B,
    i.prev.dx.H   = i_dx___H / n___H,
    i.prev.dx.W   = i_dx___W / n___W,
    prep_users = s_prep___B + s_prep___H + s_prep___W,
    prep_elig = s_prep_elig___B + s_prep_elig___H + s_prep_elig___W,
    prep_prop = prep_users / prep_elig
  )
}

process_one_calibration <- function(file_name, nsteps = 52) {
  # keep only the file name without extension and split around `__`
  name_elts <- fs::path_file(file_name) %>%
    fs::path_ext_remove() %>%
    strsplit(split = "__")

  scenario_name <- name_elts[[1]][2]
  batch_num <- as.numeric(name_elts[[1]][3])

  d <- as_tibble(readRDS(file_name))
  d <- d %>%
    filter(time >= max(time) - nsteps) %>%
    mutate_targets() %>%
    select(c(sim, all_of(names(targets)))) %>%
    group_by(sim) %>%
    summarise(across(
      everything(),
      ~ mean(.x, na.rm = TRUE)
    )) %>%
    mutate(
      scenario_name = scenario_name,
      batch = batch_num
    )

  return(d)
}

# required trackers for the calibration step
source("R/utils-epi_trackers.R")
calibration_trackers_ls <- list(
  n           = epi_n,
  i           = epi_i,
  i_dx        = epi_i_dx,
  i_sup       = epi_i_sup,
  linked1m    = epi_linked_time(4), # 1 month ~= 4 weeks
  gc_s        = epi_gc_s(c(0, 1)),  # we want the gc susceptible HIV+ and -
  ct_s        = epi_ct_s(c(0, 1)),
  s_prep      = epi_s_prep,
  s_prep_elig = epi_s_prep_elig
)

calibration_trackers <- epi_tracker_by_race(
  calibration_trackers_ls,
  full = FALSE,
  indiv = TRUE
)
