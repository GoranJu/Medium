export const isInitialized = ({ currentList, ...state }) => state[currentList].initialized;

export const totals = (state) =>
  state.listTypes.reduce(
    (acc, { namespace }) => ({
      ...acc,
      [namespace]: state[namespace].pageInfo.total || 0,
    }),
    {},
  );
