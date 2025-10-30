module.exports = {
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
    ecmaVersion: 2018,
  },
  extends: [
    "eslint:recommended",
    "google",
  ],
  rules: {
    "no-restricted-globals": ["error", "name", "length"],
    "prefer-arrow-callback": "off",
    "quotes": ["off"],
    "max-len": ["off"],
    "object-curly-spacing": ["off"],
    "indent": ["off"],
    "require-jsdoc": ["off"],
    "operator-linebreak": ["off"],
    "prefer-const": ["warn"],
    "comma-dangle": ["off"],
  },
  overrides: [
    {
      files: ["**/*.spec.*"],
      env: {
        mocha: true,
      },
      rules: {},
    },
  ],
  globals: {},
};
