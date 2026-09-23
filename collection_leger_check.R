library(tidylog)
library(dplyr)
library(ggplot2)
library(janitor)
library(broom)
library(lubridate)
library(here)
library(readxl)
library(stringr)
library(readr)


complete_check <- read_excel("Anonymized_Data/Data_completion_check.xlsx")
deleted_responses <-read_excel("Anonymized_Data/SEP_07_BEFORE_BIG_DELETE.xlsx")

names(complete_check) <- janitor::make_clean_names(names(complete_check))
names(deleted_responses ) <- janitor::make_clean_names(names(deleted_responses))

combined_data <- bind_rows(deleted_responses , complete_check) %>%
  distinct(internal_id, .keep_all = TRUE)


#Now let's get dates into the correct format 
combined_data$survey_date<- as.Date(combined_data$submitted_date)
combined_data $child_dob <- as.Date(combined_data$what_is_your_childs_date_of_birth)

#Let's make an age variable, calculated from the date of the survey and the date of birth
combined_data$child_age_years <- time_length(
  interval(combined_data$child_dob, combined_data$survey_date),
  unit = "years"
) |> floor()


write_csv(
  combined_data,
  here::here("Anonymized_Data", "combined_data.csv")
)



library(tidyverse)
library(openxlsx)

recruitment_check <- combined_data %>%
  mutate(
    # Screening questions
    screen_age_0_2 =
      please_complete_the_statement_for_yourself_check_all_that_apply_i_have_a_child_who_is_currently_0_to_2_years_old,
    
    screen_age_3_5 =
      please_complete_the_statement_for_yourself_check_all_that_apply_i_have_a_child_who_is_currently_3_to_5_years_old,
    
    screen_age_6_8 =
      please_complete_the_statement_for_yourself_check_all_that_apply_i_have_a_child_who_is_currently_6_to_8_years_old,
    
    screen_age_9_11 =
      please_complete_the_statement_for_yourself_check_all_that_apply_i_have_a_child_who_is_currently_9_to_11_years_old,
    
    screen_age_over_11 =
      please_complete_the_statement_for_yourself_check_all_that_apply_i_have_a_child_who_is_currently_older_than_11_years_old,
    
    screen_n_languages =
      how_many_languages_does_your_child_hear_regularly_at_least_8_hours_per_week,
    
    consent =
      by_clicking_on_the_i_agree_button_i_certify_that_i_have_read_the_information_and_consent_form_i_voluntarily_and_freely_consent_to_participate_in_this_research_project,
    
    # Languages actually reported
    child_english =
      what_languages_does_your_child_hear_spoken_to_them_on_a_regular_basis_at_least_8_hours_a_week_or_a_bit_over_an_hour_a_day_note_that_you_should_only_count_languages_that_people_interact_with_your_child_in_on_a_regular_basis_languages_that_they_overhear_others_speaking_or_that_they_only_hear_on_tv_or_through_digital_media_should_not_be_counted_english,
    
    child_french =
      what_languages_does_your_child_hear_spoken_to_them_on_a_regular_basis_at_least_8_hours_a_week_or_a_bit_over_an_hour_a_day_note_that_you_should_only_count_languages_that_people_interact_with_your_child_in_on_a_regular_basis_languages_that_they_overhear_others_speaking_or_that_they_only_hear_on_tv_or_through_digital_media_should_not_be_counted_french,
    
    child_first_minority =
      please_write_the_name_of_the_minority_language_that_your_child_is_exposed_to_if_your_child_is_spoken_to_in_more_than_one_minority_language_please_name_the_one_that_they_get_the_most_exposure_to_after_english_and_french_we_will_refer_to_this_language_as_your_childs_first_minority_language_in_later_questions,
    
    child_second_minority =
      please_write_the_name_of_the_second_minority_language_that_your_child_is_exposed_to_if_your_child_is_spoken_to_in_more_than_two_minority_languages_please_name_the_one_that_they_get_the_second_most_exposure_to_after_english_french_and_the_first_minority_language_we_will_refer_to_this_language_as_your_childs_second_minority_language_in_later_questions,
    
    child_third_minority =
      please_write_the_name_of_the_third_minority_language_that_your_child_is_exposed_to_the_one_that_they_get_the_least_exposure_to_we_will_refer_to_this_language_as_your_childs_third_minority_language_in_later_questions
  )


recruitment_check <- recruitment_check %>%
  mutate(
    across(
      c(
        child_english,
        child_french,
        child_first_minority,
        child_second_minority,
        child_third_minority
      ),
      ~ case_when(
        str_to_lower(str_squish(.x)) %in% 
          c("french", "français", "francais") ~ "french",
        
        str_to_lower(str_squish(.x)) %in% 
          c("english", "anglais") ~ "english",
        
        TRUE ~ str_to_lower(str_squish(.x))
      ),
      .names = "{.col}_clean"
    )
  )

recruitment_check <- recruitment_check %>%
  rowwise() %>%
  mutate(
    
    # Number of filled language fields
    n_languages_reported = sum(
      !is.na(c(
        child_english_clean,
        child_french_clean,
        child_first_minority_clean,
        child_second_minority_clean,
        child_third_minority_clean
      )) &
        c(
          child_english_clean,
          child_french_clean,
          child_first_minority_clean,
          child_second_minority_clean,
          child_third_minority_clean
        ) != ""
    ),
    
    # Number of genuinely different languages
    n_unique_languages = n_distinct(
      na.omit(c(
        child_english_clean,
        child_french_clean,
        child_first_minority_clean,
        child_second_minority_clean,
        child_third_minority_clean
      ))
    ),
    
    # A minority-language field repeats English or French
    # WHEN English/French was already reported in its dedicated field
    duplicate_official_as_minority =
      (
        child_english_clean == "english" &
          any(
            c(
              child_first_minority_clean,
              child_second_minority_clean,
              child_third_minority_clean
            ) == "english",
            na.rm = TRUE
          )
      ) |
      (
        child_french_clean == "french" &
          any(
            c(
              child_first_minority_clean,
              child_second_minority_clean,
              child_third_minority_clean
            ) == "french",
            na.rm = TRUE
          )
      ),
    
    # Any language appears more than once across the five fields
    any_duplicate_language =
      n_languages_reported > n_unique_languages
  ) %>%
  ungroup()



recruitment_check <- recruitment_check %>%
  mutate(
    
    # 1. Survey was not submitted
    exclude_not_submitted =
      is.na(status) |
      str_to_lower(str_squish(status)) != "submitted",
    
    
    # 2. Did not consent
    exclude_consent =
      !is.na(consent) & consent != "I agree",
    
    
    # 3. Failed initial age screener
    exclude_age_screen =
      (!is.na(screen_age_0_2) |
         !is.na(screen_age_9_11) |
         !is.na(screen_age_over_11)) &
      is.na(screen_age_3_5) &
      is.na(screen_age_6_8),
    
    
    # 4. Said child hears only one language
    exclude_language_screen =
      str_detect(
        str_to_lower(coalesce(screen_n_languages, "")),
        "^one language"
      ),
    
    
    # 5a. Developmental-delay question missing
    # Due to survey design error
    exclude_developmental_missing =
      is.na(
        has_your_child_been_diagnosed_with_a_speech_disorder_or_a_language_delay
      ),
    
    
    # 5b. Developmental concern reported
    # Anything other than "No" is excluded
    exclude_developmental_response =
      !is.na(
        has_your_child_been_diagnosed_with_a_speech_disorder_or_a_language_delay
      ) &
      str_to_lower(
        str_squish(
          has_your_child_been_diagnosed_with_a_speech_disorder_or_a_language_delay
        )
      ) != "no",
    
    
    # 6. Actual age outside 3;0–8;11
    exclude_actual_age =
      !is.na(child_age_years) &
      (child_age_years < 3 | child_age_years >= 9),
    
    
    # 7. Did they reach the detailed language section?
    reached_language_section =
      if_any(
        c(
          child_english,
          child_french,
          child_first_minority,
          child_second_minority,
          child_third_minority
        ),
        ~ !is.na(.x)
      ),
    
    
    # 8. Fewer than two unique languages
    exclude_less_than_2_languages =
      reached_language_section &
      n_unique_languages < 2,
    
    
    # 9. Same language entered in multiple fields
    exclude_language_inconsistency =
      reached_language_section &
      any_duplicate_language
  )


recruitment_check <- recruitment_check %>%
  rowwise() %>%
  mutate(
    
    exclusion_reason = paste(
      c(
        if (isTRUE(exclude_not_submitted))
          "Survey not submitted",
        
        if (isTRUE(exclude_consent))
          "Did not agree to participate",
        
        if (isTRUE(exclude_age_screen))
          "Ineligible age reported in screening question",
        
        if (isTRUE(exclude_language_screen))
          "Reported hearing only one language in screening question",
        
        if (isTRUE(exclude_developmental_missing))
          "developmental concern no response",
        
        if (isTRUE(exclude_developmental_response))
          "Developmental concern reported",
        
        if (isTRUE(exclude_actual_age))
          "Child's actual age is outside 3;0–8;11",
        
        if (isTRUE(exclude_less_than_2_languages))
          "Fewer than 2 unique languages reported",
        
        if (isTRUE(exclude_language_inconsistency))
          "Inconsistent language reporting: same language reported in multiple language fields"
      ),
      collapse = "; "
    ),
    
    keeper = if_else(
      exclusion_reason == "",
      "Yes",
      "No"
    ),
    
    exclusion_reason = na_if(
      exclusion_reason,
      ""
    )
  ) %>%
  ungroup()


recruitment_check %>%
  count(keeper)



recruitment_check %>%
  summarise(
    not_submitted =
      sum(exclude_not_submitted, na.rm = TRUE),
    
    did_not_consent =
      sum(exclude_consent, na.rm = TRUE),
    
    failed_age_screen =
      sum(exclude_age_screen, na.rm = TRUE),
    
    failed_language_screen =
      sum(exclude_language_screen, na.rm = TRUE),
    
    survey_design_error =
      sum(exclude_developmental_missing, na.rm = TRUE),
    
    developmental_concern =
      sum(exclude_developmental_response, na.rm = TRUE),
    
    actual_age_ineligible =
      sum(exclude_actual_age, na.rm = TRUE),
    
    fewer_than_2_languages =
      sum(exclude_less_than_2_languages, na.rm = TRUE),
    
    inconsistent_languages =
      sum(exclude_language_inconsistency, na.rm = TRUE)
  )


recruitment_check %>%
  filter(
    exclude_less_than_2_languages |
      exclude_language_inconsistency
  ) %>%
  select(
    internal_id,
    hidden_pid,
    child_english,
    child_french,
    child_first_minority,
    child_second_minority,
    child_third_minority,
    n_languages_reported,
    n_unique_languages,
    exclude_less_than_2_languages,
    exclude_language_inconsistency,
    exclusion_reason
  ) %>%
  View()


recruitment_check %>%
  filter(keeper == "No") %>%
  select(
    internal_id,
    hidden_pid,
    child_age_years,
    screen_n_languages,
    child_english,
    child_french,
    child_first_minority,
    child_second_minority,
    child_third_minority,
    exclusion_reason
  ) %>%
  View()

recruitment_check %>%
  filter(keeper == "Yes") %>%
  View()


recruitment_company <- recruitment_check %>%
  select(
    internal_id,
    hidden_pid,
    keeper,
    exclusion_reason
  )



write.xlsx(
  recruitment_company,
  here::here("recruitment_company_eligibility.xlsx"),
  overwrite = TRUE
)
