export default {
  "minion/config-channels/minion-config-channels": () => import("./config-channels/minion-config-channels"),
  "minion/formula/minion-formula": () => import("./formula/minion-formula.renderer"),
  "minion/formula/minion-formula-selection": () => import("./formula/minion-formula-selection.renderer"),
  "minion/packages/package-states": () => import("./packages/package-states.renderer"),
};
