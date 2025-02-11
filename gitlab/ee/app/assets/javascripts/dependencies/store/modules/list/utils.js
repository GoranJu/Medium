export const hasDependencyList = ({ dependencies }) => Array.isArray(dependencies);
export const isValidResponse = ({ data }) => Boolean(data && hasDependencyList(data));
