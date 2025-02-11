import Vue from 'vue';
import apolloProvider from 'ee/subscriptions/graphql/graphql';
import CompanyForm from 'ee/registrations/components/company_form.vue';
import GlFieldErrors from '~/gl_field_errors';

const mountCompanyForm = () => {
  const el = document.querySelector('#js-registrations-company-form');
  const { submitPath, firstName, lastName, emailDomain, formType, trackActionForErrors } =
    el.dataset;

  return new Vue({
    el,
    apolloProvider,
    provide: {
      user: {
        firstName,
        lastName,
        emailDomain,
      },
      submitPath,
      trackActionForErrors,
      formType,
    },
    render(createElement) {
      return createElement(CompanyForm);
    },
  });
};

export default () => {
  mountCompanyForm();

  // Since we replaced form inputs, we need to re-initialize the field errors handler
  return new GlFieldErrors(document.querySelectorAll('.gl-show-field-errors'));
};
