const wearRoutes = [
  {
    path: "/wear",
    component: () => import("layouts/WearLayout.vue"),
    children: [
      { path: "", redirect: "/wear/wallet" },
      {
        path: "wallet",
        component: () => import("src/pages/wear/WearWalletPage.vue"),
      },
      {
        path: "send",
        component: () => import("src/pages/wear/WearSendPage.vue"),
      },
      {
        path: "receive",
        component: () => import("src/pages/wear/WearReceivePage.vue"),
      },
      {
        path: "history",
        component: () => import("src/pages/wear/WearHistoryPage.vue"),
      },
    ],
  },
];

export default wearRoutes;
