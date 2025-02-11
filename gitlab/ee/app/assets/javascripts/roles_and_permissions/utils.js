import { TYPENAME_MEMBER_ROLE } from '~/graphql_shared/constants';

export const isCustomRole = ({ __typename }) => __typename === TYPENAME_MEMBER_ROLE;
