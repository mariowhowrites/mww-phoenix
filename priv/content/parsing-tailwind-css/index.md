title: Parsing Open Source - Tailwind CSS
published: true
description: Peeking under the hood of everyone's favorite customizable CSS utility framework
tags: 
  - tailwindcss
  - javascript
  - nodejs 
  - postcss
category: Technical
date: "2019-04-05T22:12:03.284Z"
slug: parsing-tailwind-css
---

Perhaps no single tool entered my developer workflow immediately after release as quickly as Tailwind CSS. I've always been a huge CSS fan. My first foray into web development was a mission to alter a sidebar on my WordPress blog, back before I knew what CSS was or how it worked.

However, for as long as I've loved CSS as a language, I've struggled to scale CSS in my projects. No matter how I organized my stylesheets, I always reached a point in my code where I was too afraid to touch anything. My stylesheets were arranged as a house of cards, ready to fall apart at the first sign of customization.

It was for this reason that I adopted the utility-based approach of Tailwind CSS. However, it's always struck me as a bit of a black box: I edit a JavaScript file, add a line to my `package.json`, and boom! CSS. So for these chapters of Parsing Open Source, I'm digging through the inner workings of Tailwind CSS.

This first chapter will cover a top-level overview of the Tailwind CSS codebase. This includes both the specifics of Tailwind's architecture and how it interacts with PostCSS, the framework upon which Tailwind is built. A second chapter will examine more specific implementation details; the original draft of this column with all details included was both long and intimidating, which is the opposite of my intention in this series.

My goals for this series are twofold: one, to help demystify the process of examining open-source code; two, to help improve my own understanding of how large-scale JavaScript projects are organized and implemented.

## Tailwind and PostCSS

Ultimately, Tailwind CSS is a PostCSS plugin. So in order to understand how TailwindCSS works, it's helpful to understand how PostCSS works.

PostCSS is a powerful library with a deceptively simply API. Essentially, it does two things:

1. Converts CSS files into JS.
2. Converts JS files into CSS.

Why would you want to turn CSS into JS and vice versa?

CSS is an immensely powerful language, but it lacks many scripting features that define Turing-complete languages. It doesn't have loops, recursion, etc., and doesn't offer an easy way to programmatically generate itself.

These features are all found in JavaScript. By converting CSS into JavaScript, developers can then modify that CSS, add new rules, and so on using all the programmatic power of a scripting language like JavaScript.

Then, once the JavaScript "stylesheets" has been customized to the developers' liking, PostCSS offers an API to turn that JavaScript back into a CSS file, ready to use on every website on the Internet.

Going into the specifics of how PostCSS accomplishes this is, to use a scientific term, "2deep4me". However, it is important to know the basics of how PostCSS handles the conversion to and from JavaScript, as these details are exposed in the PostCSS API used throughout Tailwind.

Basically, when PostCSS converts CSS into JavaScript, it chooses to store the stylesheet information in a data structure called an **abstract syntax tree (AST).** ASTs are one of those computer science concepts that sound much more complex than they actually are.

Before continuing, let's refresh ourselves quickly on some CSS terminology. Here's a diagram I found on the Internet going over the anatomy of a given CSS rule:

![CSS Rule Anatomy Diagram](https://i.imgur.com/RIW7J2A.png)

Source: [https://ryanbroome.wordpress.com/2011/10/13/css-cascading-style-sheet/](https://ryanbroome.wordpress.com/2011/10/13/css-cascading-style-sheet/)

As you can see, everything from the `h1` selector to the closing bracket makes up one distinct CSS **rule.** Within the rule, there can be any number of **declarations**. In the case of the diagram above, there are two declarations. One declares the color to be the hex value `#333`, while the other declares the font size to be the value `x-large`.

If we were to think of this rule as a tree, we could say that the rule itself is the root, or the parent, while each declaration is a leaf, or a child. Here's an shoddy diagram I created to illustrate the point:

![CSS Rule Tree Diagram](https://i.imgur.com/tw9qxxG.png)

Stepping out a level, we could also apply this same line of thinking to the entire stylesheet. With the stylesheet as our parent, we could consider each rule within the stylesheet to be a child of the parent stylesheet.

![CSS Stylesheet Tree Diagram](https://i.imgur.com/bCgoRnE.png)

Basically, what PostCSS does is convert CSS into a tree similar to the diagram above. Your stylesheet is the root node, each rule is a leaf of the document root, and each individual declaration is a leaf of the rule where it is defined. Once the whole tree is constructed, any PostCSS plugin can "walk" the stylesheet by looping over each rule before repeating the process to "walk" across the rule to each declaration. With a given rule or declaration in hand, plugins can make any necessary changes to the stylesheet by utilizing the PostCSS API.

With this understanding in mind, let's look at a sample PostCSS plugin, taken from [Dockyard's tutorial on how to write a plugin](https://dockyard.com/blog/2018/02/01/writing-your-first-postcss-plugin):

```js
var postcss = require("postcss")
module.exports = postcss.plugin("postcss-test-plugin", function() {
  return function(root) {
    root.walkRules(function(rule) {
      rule.walkDecls(/^overflow-?/, function(decl) {
        if (decl.value === "scroll") {
          var hasTouch = rule.some(function(i) {
            return i.prop === "-webkit-overflow-scrolling"
          })
          if (!hasTouch) {
            rule.append({
              prop: "-webkit-overflow-scrolling",
              value: "touch",
            })
          }
        }
      })
    })
  }
})
```

Knowing what we know about how PostCSS works, we can say that this plugin does the following:

1. Accepts a spreadsheet as the `root` argument of the top-level function.
2. Walks through each rule of the spreadsheet.
3. Within each rule, walks through each declaration that matches the RegEx pattern `/^overflow-?/`. In other words, finds each declaration that begins with the phrase `overflow-`.
4. If the declaration has a value of `scroll`, checks to see whether any other declaration in the rule defines a property of `-webkit-overflow-scrolling`.
5. If not, adds such a declaration to the rule, and give it the value `touch`.

Hopefully this example offers a glimpse into the power of PostCSS. Editing CSS programmatically would be impossible if we were just working with CSS. Instead, by translating CSS into a JavaScript AST, we can then walk the tree and edit our stylesheets using the full suite of tools available in JavaScript.

If we want to get super technical, the approach used to navigate the tree in this example is **depth-first traversal**, as we are fully examining each individual declaration of a rule before moving onto the next rule. That's not strictly necessary to understand how Tailwind works, but I always like to pair theoretical concepts with real-world scenarios where possible so that the theory seems a little less abstract.

Now that we have a bit more knowledge as to the context in which TailwindCSS operates, let's start looking at some code!

## The Tailwind API

There are two places I like to start when parsing open source repositories. The first is the public API — ie. what happens when a developer invokes the repository in their own project. The second is the test coverage — ie. what tests a given repo has written to ensure their code works as intended. In that spirit, looking at the Tailwind documentation as well as the tests, we can start with the following two code snippets. The first is taken from the Webpack setup instructions using a `postcss.config.js` file, while the second is taken from the `sanity.test.js` file included in the `__tests__` directory of Tailwind's repo:

```js
var tailwindcss = require("tailwindcss")

module.exports = {
  plugins: [
    // ...
    tailwindcss("./path/to/your/tailwind.js"),
    require("autoprefixer"),
    // ...
  ],
}
```

```js
import tailwind from "../src/index"

it("generates the right CSS", () => {
  const inputPath = path.resolve(`${__dirname}/fixtures/tailwind-input.css`)
  const input = fs.readFileSync(inputPath, "utf8")

  return postcss([tailwind()])
    .process(input, { from: inputPath })
    .then(result => {
      const expected = fs.readFileSync(
        path.resolve(`${__dirname}/fixtures/tailwind-output.css`),
        "utf8"
      )

      expect(result.css).toBe(expected)
    })
})
```

While the two code snippets ostensibly achieve the same goal, we can see that the two implementations differ considerably. These differences mostly boil down to the two different contexts in which these code snippets are designed to run. The Webpack example is meant to be used as one part of a comprehensive project, while the Jest code example is meant to fully simulate the interactions with PostCSS that would, in the first example, be handled by Webpack.

Let's focus on the similarities: both code examples invoke a `tailwind` function, although the function is called `tailwindcss` in the first example to match the name of the NPM package. We see that, although the Webpack example assumes that your project is using its own configuration file, a custom config is not strictly necessary to use Tailwind, as a fallback default is used instead.

Furthermore, although the CSS file is not defined in the `postcss.config.js` file, we know from looking at the documentation and at the [webpack-starter](https://github.com/tailwindcss/webpack-starter) project that both the real-world and test examples take in a CSS stylesheet as a required argument. In the Jest example, the CSS input file is fetched from a `fixtures` directory within the tests folder and loaded into JavaScript using the `path` and `fs` modules, which are native to NodeJS.

Inspecting the `tailwind-input` file, we see that it closely mirrors the example setup in the Tailwind documentation:

```css
@tailwind base;

@tailwind components;

@tailwind utilities;

@responsive {
  .example {
    @apply .font-bold;
    color: theme("colors.red.500");
  }
}
```

This file is run through PostCSS using the `process` method, which produces a string representation of a CSS file. This output is then compared against a `tailwind-output.css` file, which includes all of the default Tailwind styles plus the following `example` styles:

```css
.example {
  font-weight: 700;
  color: #f56565;
}

... .sm\:example {
  font-weight: 700;
  color: #f56565;
}

... .md\:example {
  font-weight: 700;
  color: #f56565;
}

/* other responsive classes below */
```

If the CSS returned from PostCSS's `process` function matches the output of this file, the test passes — which, as of publication, it does.

## Implementing Tailwind

We now know that the main export of Tailwind is a PostCSS plugin. We also know that it is a function that takes a single argument: the (optional) path to a Tailwind config file. With that in mind, let's take a look at how the `tailwind` function is exported. We can find it in the `src/index.js` file within the TailwindCSS repo:

```js
const plugin = postcss.plugin("tailwind", config => {
  const plugins = []
  const resolvedConfigPath = resolveConfigPath(config)

  if (!_.isUndefined(resolvedConfigPath)) {
    plugins.push(registerConfigAsDependency(resolvedConfigPath))
  }

  return postcss([
    ...plugins,
    processTailwindFeatures(getConfigFunction(resolvedConfigPath || config)),
    perfectionist({
      cascade: true,
      colorShorthand: true,
      indentSize: 2,
      maxSelectorLength: 1,
      maxValueLength: false,
      trimLeadingZero: true,
      trimTrailingZeros: true,
      zeroLengthNoUnit: false,
    }),
  ])
})
```

From a top-level perspective, we can see that the following things are happening within this plugin:

- The configuration file is resolved from the path argument of `tailwindcss()`.
- The resolved config as added as a dependency. As far as I can tell, this is solely used for Webpack push notifications during the build process, but someone please let me know if it's used in some way I'm not aware of.
- A PostCSS plugin is returned where the following steps happen:
  - The dependency is registered.
  - Tailwind features are processed using a configuration function built from the resolved configuration path.
  - The resulting CSS is cleaned up using the `perfectionist` PostCSS plugin.

The `resolveConfigPath` function is fairly straightforward:

```js
function resolveConfigPath(filePath) {
  if (_.isObject(filePath)) {
    return undefined
  }

  if (!_.isUndefined(filePath)) {
    return path.resolve(filePath)
  }

  try {
    const defaultConfigPath = path.resolve(defaultConfigFile)
    fs.accessSync(defaultConfigPath)
    return defaultConfigPath
  } catch (err) {
    return undefined
  }
}
```

Here we see some of the first usages of `lodash`, which is an immensely popular [JavaScript utility library](https://lodash.com/). Lodash is used throughout the Tailwind repository, and I often had the Lodash documentation open while writing this analysis to grok some of the more complicated logic.

This function allows for the following possible outcomes:

- The filepath is an object — the config has already been loaded, so return nothing.
- The filepath exists and is not an object — it is a string, so try and resolve it using NodeJS's `path` module.
- The filepath does not exist — load the default configuration, but return nothing if the necessary file permissions do not allow access to the default config.

This function confirms our earlier conclusion; a configuration file is not necessary to run TailwindCSS, as it will use the default configuration if the path is undefined.

Let's briefly look at `getConfigFunction`, the other function defined directly within `index.js`:

```js
const getConfigFunction = config => () => {
  if (_.isUndefined(config) && !_.isObject(config)) {
    return resolveConfig([defaultConfig])
  }

  if (!_.isObject(config)) {
    delete require.cache[require.resolve(config)]
  }

  return resolveConfig([
    _.isObject(config) ? config : require(config),
    defaultConfig,
  ])
}
```

This function covers the following possibilities:

- The config is undefined and not an object — resolve config with the default.
- The config is not an object — it is a string. Delete the cached version of the config, then resolve configuration with the passed-in configuration and the default config.

The one part of this function that might look a bit strange is the line beginning with `delete require.cache`. This method has to do with the way NodeJS's `require` function works. When you `require` something with NodeJS, the result is loaded and stored in a cache. When you `require` that file again, NodeJS looks to the cache first. If it finds the file you requested, it will load the file from cache rather than refetching the whole library again.

In most cases, this is the ideal behavior. If you use Lodash in 20 places in your code, for example, you don't want to load Lodash 20 times, as that would slow down your code significantly.

However, in this case, we are using `require` on our configuration file. Because our config can and likely will change, we want to ensure that the config we eventually load is the valid configuration at the time the code is run. Therefore, before loading the new cache, we must delete the old cache first.

I'm going to leave the details of the `resolveConfig` function for the next chapter, as it's a bit of a doozy. Suffice it to say for now that this function's primary responsibility is to merge any user-supplied configuration with the default configuration, overriding the default where necessary. Here's the first test from `resolveConfig.test.js`, which provides a basic example of how the function works:

```js
test("prefix key overrides default prefix", () => {
  const userConfig = {
    prefix: "tw-",
  }

  const defaultConfig = {
    prefix: "",
    important: false,
    separator: ":",
    theme: {
      screens: {
        mobile: "400px",
      },
    },
    variants: {
      appearance: ["responsive"],
      borderCollapse: [],
      borderColors: ["responsive", "hover", "focus"],
    },
  }

  const result = resolveConfig([userConfig, defaultConfig])

  expect(result).toEqual({
    prefix: "tw-",
    important: false,
    separator: ":",
    theme: {
      screens: {
        mobile: "400px",
      },
    },
    variants: {
      appearance: ["responsive"],
      borderCollapse: [],
      borderColors: ["responsive", "hover", "focus"],
    },
  })
})
```

You can see that the user-supplied `prefix` key overrides the default `prefix`, but all other default values are preserved in the final result.

In the end, what the `getConfigFunction` returns is a function that will create the proper configuration file for Tailwind to use, based on a combination of user-provided and default settings.

By this point, we've covered the parts of Tailwind that create context in which the PostCSS plugin can exist. Now, with the `processTailwindFeatures` function, let's look at the "meat and potatoes" of the repository.

## Processing Tailwind Features

The `processTailwindFeatures` function is where styles and configuration combine to create a stylesheet. Because the `perfectionist` plugin accepts a stylesheet as its input, we know that what is returned from `processTailwindFeatures` is a PostCSS plugin that returns a string containing our CSS rules.

Let's take a look at that function now:

```js
export default function(getConfig) {
  return function(css) {
    const config = getConfig()
    const processedPlugins = processPlugins(
      [...corePlugins(config), ...config.plugins],
      config
    )

    return postcss([
      substituteTailwindAtRules(config, processedPlugins),
      evaluateTailwindFunctions(config),
      substituteVariantsAtRules(config, processedPlugins),
      substituteResponsiveAtRules(config),
      substituteScreenAtRules(config),
      substituteClassApplyAtRules(config, processedPlugins.utilities),
    ]).process(css, { from: _.get(css, "source.input.file") })
  }
}
```

At a glance, we can outline four major steps happening here:

1. Using the parameter passed to `processTailwindFeatures` (ie. `getConfigFunction`) the configuration file is retrieved.
2. With the config in hand, the core Tailwind plugins are combined with any user-defined plugins using the `processPlugins` function to create a PostCSS AST of our Tailwind styles.
3. That AST is then passed into a PostCSS plugin chain. Each step of that chain uses the config and the AST to incrementally create a fully-formatted CSS output, complete with responsive rules, variants, and components built with Tailwind's `@apply` directive.
4. Finally, the output of the PostCSS plugin chain is processed and returned as a CSS file using the `process` method.

We've already covered the basics of step #1, so we won't go over it again here except to remind ourselves that the return value of `getConfig` is an object containing our final configuration.

Step #2 is where things start to get interesting. There are two functions to consider here. `corePlugins` handles the loading of all the Tailwind default plugins, while `processPlugins` transforms all core and user-defined plugins into a PostCSS AST for use within the PostCSS plugin chain.

Let's look at `corePlugins` first:

```js
export default function({ corePlugins: corePluginConfig }) {
  return configurePlugins(corePluginConfig, {
    preflight,
    container,
    appearance,
    backgroundAttachment,
    // ... the rest of Tailwind core here
    zIndex,
  })
}
```

We can see that `corePlugins` does two things:

1. It loads all core plugins from the `plugins` directory.
2. It applies the `corePlugins` property from our config to configure each core plugin using `configurePlugins`.

The `configurePlugins` method is also quite simple:

```js
export default function(pluginConfig, plugins) {
  return Object.keys(plugins)
    .filter(pluginName => {
      return pluginConfig[pluginName] !== false
    })
    .map(pluginName => {
      return plugins[pluginName]()
    })
}
```

Basically, what this does is remove any core plugin that the user has specifically disallowed within their configuration. So, if I decided not to include any padding styles within my final Tailwind CSS file, I could add something like this to my configuration:

```js
{
  corePlugins: {
    padding: false
  }
}
```

Keep in mind that the comparison is done using strict equality, ie. `!==` vs `!=`. Because `undefined !== false`, this means that no plugins will be excluded unless explicitly excluded in user config. By default, all plugins are included, as the configuration `corePlugins` property defaults to an empty object.

Next, we turn to the `processPlugins` function:

```js
export default function(plugins, config) {
  const pluginBaseStyles = []
  const pluginComponents = []
  const pluginUtilities = []
  const pluginVariantGenerators = {}

  const applyConfiguredPrefix = selector => {
    return prefixSelector(config.prefix, selector)
  }

  plugins.forEach(plugin => {
    plugin({
      postcss,
      config: (path, defaultValue) => _.get(config, path, defaultValue),
      e: escapeClassName,
      prefix: applyConfiguredPrefix,
      addUtilities: (utilities, options) => {
        const defaultOptions = {
          variants: [],
          respectPrefix: true,
          respectImportant: true,
        }

        options = Array.isArray(options)
          ? Object.assign({}, defaultOptions, { variants: options })
          : _.defaults(options, defaultOptions)

        const styles = postcss.root({ nodes: parseStyles(utilities) })

        styles.walkRules(rule => {
          if (options.respectPrefix) {
            rule.selector = applyConfiguredPrefix(rule.selector)
          }

          if (options.respectImportant && _.get(config, "important")) {
            rule.walkDecls(decl => (decl.important = true))
          }
        })

        pluginUtilities.push(wrapWithVariants(styles.nodes, options.variants))
      },
      addComponents: (components, options) => {
        options = Object.assign({ respectPrefix: true }, options)

        const styles = postcss.root({ nodes: parseStyles(components) })

        styles.walkRules(rule => {
          if (options.respectPrefix) {
            rule.selector = applyConfiguredPrefix(rule.selector)
          }
        })

        pluginComponents.push(...styles.nodes)
      },
      addBase: baseStyles => {
        pluginBaseStyles.push(...parseStyles(baseStyles))
      },
      addVariant: (name, generator) => {
        pluginVariantGenerators[name] = generateVariantFunction(generator)
      },
    })
  })

  return {
    base: pluginBaseStyles,
    components: pluginComponents,
    utilities: pluginUtilities,
    variantGenerators: pluginVariantGenerators,
  }
}
```

Now, while this function might _look_ like a doozy, it's actually not as bad as it looks. More importantly, there's a reason why everything is stacked together in one function instead of being split up into separate functions.

We'll get to the `plugins.forEach` loop in a moment, but to understand why this loop is structured as it is, let's take a quick look at the `applyConfiguredPrefix` function:

```js
const applyConfiguredPrefix = selector => {
  return prefixSelector(config.prefix, selector)
}
```

There are two things to notice here that together help explain the following `plugins.forEach` loop. The first is that, to use the formal definition, `applyConfiguredPrefix` is a **function expression**, not a **function declaration.** Less formally, the function takes the form of

```js
const functionExpression = function() {
  // your function here
}
```

And not the form of:

```js
function functionDeclaration() {
  // your function here
}
```

If you're new to JavaScript, or coming from another programming language, this distinction might seem arbitrary and confusing. While I agree that the syntax could probably be a bit clearer, there is a specific reason for this distinction, and it has to do with the second thing we should notice about `applyConfiguredPrefix`. Specifically, we should note that, although the function uses `config.prefix`, the only argument that the function accepts is `selector`. Nowhere inside the function is `config` defined, yet we are able to use it just the same. Why is that?

The answer has to do with the way the JavaScript engine interprets JavaScript code when executing it. Essentially, two things happen in order:

1. All function declarations are "hoisted", making them available to the rest of your code. This means that you could declare a function at the end of your code and use it at the beginning of your code without a problem.
2. All remaining code is executed top-to-bottom, including function expressions.

What this means in context is that, because `applyConfiguredPrefix` is a function expression defined within `processPlugins`, any variables that are accessible to `processPlugins` by the time `applyConfiguredPrefix` is defined are also accessible within `applyConfiguredPrefix`. Because our config is passed into `processPlugins` as a parameter, it can be used without being specifically passed into `applyConfiguredPrefix`.

By contrast, had a function declaration been used instead, the function would have looked like this:

```js
function applyConfiguredPrefix(selector) {
  // because config is not passed in explicitly...
  return prefixSelector(config.prefix, selector) // this would have thrown an error!
}
```

Because this function would have been "hoisted", we would not have had access to `config` unless we explicitly defined it as a parameter.

Confusing? I know it was for me when I started. This is one of those JavaScript features that, while powerful, can be a bit hard to parse even for experienced developers. I started my web development journey with PHP, and while the language does have its warts, I personally believe it handles this scenario a bit more directly. Such a function in PHP would have looked like:

```php
function applyConfiguredPrefix($selector) use ($config) {
    return prefixSelector($config->prefix, $selector);
}
```

You can see specifically which variables this function depends on because they are defined in the `use` clause, which to me is far less confusing. But, I digress.

To see why this distinction between expressions and declarations is so important here, let's return to our `plugins.forEach` loop.

On a surface level, what's happening is that every plugin in Tailwind, whether defined in core or by the user, is invoked with the same parameter: an object with various methods that the plugin can use.

We see that virtually all of the methods defined on this parameter are function expressions, such as the `config` method:

```js
{
  // previous methods
  config: (path, defaultValue) => _.get(config, path, defaultValue),
  // ... the rest of the plugin methods
}
```

Here, the colon indicates that this is a function expression. If it were a function declaration, it would instead be defined like this:

```js
{
  config(path, defaultValue) {
    return _.get(config, path, defaultValue) // error: config is undefined
  },
}
```

Because an expression is used instead of a declaration, `config` can be referenced just as it was in `applyConfiguredPrefix`.

Now, at this point you might be wondering: why go to all this trouble to avoid passing in another parameter? Wouldn't it be easier just to pass `config` into this method explicitly?

In this case, since we are simply reading from `config` and not editing it, this might be true. However, to see the true utility of function expressions, let's take a look at another one of the methods: `addUtilities`.

```js
const pluginUtilities = []
// ... within plugin.forEach loop:
{
  addUtilities: (utilities, options) => {
    const defaultOptions = { variants: [], respectPrefix: true, respectImportant: true }

    options = Array.isArray(options)
      ? Object.assign({}, defaultOptions, { variants: options })
      : _.defaults(options, defaultOptions)

    const styles = postcss.root({ nodes: parseStyles(utilities) })

    styles.walkRules(rule => {
      if (options.respectPrefix) {
        rule.selector = applyConfiguredPrefix(rule.selector)
      }

      if (options.respectImportant && _.get(config, 'important')) {
        rule.walkDecls(decl => (decl.important = true))
      }
    })

    pluginUtilities.push(wrapWithVariants(styles.nodes, options.variants))
  },
}
```

Before parsing the rest of the method, let's look at the final line, where the method's results are pushed into `pluginUtilities`. Remember that the `pluginUtilities` array is defined **before** the plugin loop. Because `addUtilities` is a function expression that occurs after `pluginUtilities` is defined, it has access to the `pluginUtilities` array. Importantly, this means that it can also change the value of `pluginUtilities`.

Altering the array in this manner would not be possible if `pluginUtilities` was instead passed in as a parameter. Because all function declarations have their own scope, any changes made to the array within `addUtilities` would be discarded when the method stopped executing, leaving the original array unchanged.

Whew! With that out of the way, let's look at the function itself, shall we?

We see that the following actions are happening:

1. An object of default options is created.
2. We check the user-provided options passed into the method. Are the options an array?
   1. If so, the options parameter is an array of supported variants. Create a new object with our default options, and replace the default variants with the user-provided variants array.
   2. If not, the parameter is instead a full options object. Merge this object with the defaults using Lodash's `defaults` function.
3. Using PostCSS's `root` method, we create a PostCSS AST from the result of applying the `parseStyles` function to the provided utilities.
4. We walk over the rules of the newly-created PostCSS AST, applying prefixes and adding important declarations as necessary.
5. As mentioned before, we push the resulting AST onto the `pluginUtilities` array alongside any variants specified in the options object.

In summary, whatever utilities are passed to `addUtilities` are parsed with PostCSS and modified by the default options, as well as any options passed by the plugin itself.

To further contextualize this method, let's look at how it's used by one of the core plugins. We'll pick the `display` plugin, as it's a simple plugin defining widely-used CSS styles:

```js
export default function() {
  return function({ addUtilities, config }) {
    addUtilities(
      {
        ".block": {
          display: "block",
        },
        ".inline-block": {
          display: "inline-block",
        },
        ".inline": {
          display: "inline",
        },
        ".flex": {
          display: "flex",
        },
        ".inline-flex": {
          display: "inline-flex",
        },
        ".table": {
          display: "table",
        },
        ".table-row": {
          display: "table-row",
        },
        ".table-cell": {
          display: "table-cell",
        },
        ".hidden": {
          display: "none",
        },
      },
      config("variants.display")
    )
  }
}
```

The plugin itself doesn't contain much logic, instead delegating to the `processPlugins` methods to handle most of its functionality.

The `addUtilities` method is invoked with two arguments. The first is the object containing key/value pairs representing all styles that should be added as part of the plugin. The second is the options object, which in this case is pulled directly from the configuration key `variants.display`.

You might have noticed a contradiction in how I've described PostCSS versus how it's used in this case. When describing PostCSS originally, I said that it accepted a CSS stylesheet and converted that stylesheet into a JavaScript AST. However, we see here that the first argument passed to `addUtilities`, which is converted to an AST using PostCSS's `process` method, is not a stylesheet but an object. What gives? Am I snickering to myself, relishing in how my long-running deception has finally come full circle?

Fear not, dear reader. I would not lead you this far into the rabbit hole only to bamboozle you now. If I am snickering, it is only because as I write this, my cat has just tackled my unsuspecting mini Daschund like a safety pile-driving a wide receiver.

The answer lies within the `parseStyles` method, which eventually delegates to the `parseObjectStyles` function:

```js
import _ from "lodash"
import postcss from "postcss"
import postcssNested from "postcss-nested"
import postcssJs from "postcss-js"

export default function parseObjectStyles(styles) {
  if (!Array.isArray(styles)) {
    return parseObjectStyles([styles])
  }

  return _.flatMap(
    styles,
    style =>
      postcss([postcssNested]).process(style, { parser: postcssJs }).root.nodes
  )
}
```

In particular, the last line is what interests us. We've seen PostCSS's `process` method before, but what we haven't seen is the second argument, an options object which here specifies a custom parser: `postcssJs`. With this parser downloaded from NPM and configured in our processor, we can take a JavaScript object formatted like the object in the `display` plugin and turn it into an PostCSS AST as if it were a stylesheet.

When all is said and done, the `processPlugins` function returns an object containing four PostCSS ASTs:

- base
- components
- utilities
- variantGenerators

These ASTS are then used in the PostCSS plugin chain. The resulting ASTs are combined and compiled into a stylesheet, cleaned up by Perfectionist, and written to your project's CSS file, ready to help craft your beautiful and semantic websites.

## Summing Up: Tailwind Patterns and Structures

We've covered a lot of ground in this analysis. We've hopefully learned something about Tailwind and PostCSS, and maybe we've learned a thing or two about JavaScript along the way.

There are a couple functions I've left off this analysis. In particular, `resolveConfig` and the entire `processTailwindFunctions` PostCSS plugin chain remain unparsed, as do some of the more complex Tailwind plugins included in core.

But even leaving those loose ends for the next chapter, we've still managed to uncover some of the more prevalent patterns used throughout TailwindCSS. Let's go through some of them now:

### PostCSS

Though you probably knew already that TailwindCSS was a PostCSS plugin, it may have surprised you to find out how deeply PostCSS is integrated into the plugin. At virtually every depth, PostCSS functions are used to create and compose plugins, as well as parse and navigate ASTs. Accordingly, TailwindCSS makes heavy use of the tree structures created by PostCSS in order to figure out where and how to build its stylesheet output.

### Functional Programming

One pattern we didn't discuss was the use of functional programming throughout TailwindCSS. You'll notice the codebase contained no classes and no inheritance, either class-based or prototypal. Instead, in keeping with the PostCSS API, which heavily emphasizes function-based code structures, virtually all of Tailwind's functionality is encapsulated within functions. Furthermore, the use of Lodash, a utility library emphasizing functional programming through the use of function chaining and common higher-order functions, solidifies TailwindCSS as adhering to a functional programming style.

It is important to note, however, that the functions used in Tailwind weren't exactly pure, for reasons we'll talk about in the next section.

### Function Expressions

We noted a couple instances in which function expressions were used in place of function declarations. Function expressions are a good way of leveraging the power of functions while maintaining state at a high level. By binding top-level variables into localized functions, TailwindCSS is able to accomplish things such as the plugin processing loop, where many plugins are handled in a functional way without needing to resort to imperative and sometimes-clunky `for` loops.

As mentioned above, this does mean that Tailwind's functional programming is not "pure" in a strict sense. Pure functional programming means simply that functions only accept inputs and return outputs. Notably, pure functional programming does not allow for the use of "side effects", or modifying state that is not returned. We saw that the plugin processing loop breaks this rule, as the top-level arrays were defined outside the loop and modified in the functions defined within the loop.

In general this is not a bad thing, and one of the primary strengths of JavaScript is its ability to support multiple different styles of programming in one language. The primary drawback of nonpure functions is that the programmer needs to take extra care to ensure that state is not modified in unexpected ways. Assuming this is done, and everything I saw in the codebase assured me that it is, the debate about functional purity is more academic than consequential in a real-world sense.

## Signing Off

That's it for this chapter of Parsing Open Source! Chapter 2 of TailwindCSS is forthcoming. I have plans to cover GatsbyJS and Laravel next, but do let me know if there are any open source libraries you'd like to see analyzed. I write primarily PHP and JavaScript, but I relish the opportunity to dive into new languages and repos. I'm here and on Twitter @mariowhowrites.

But don't request anything in Python. Indentation as syntax is evil and I won't stand for it. Don't @ me.
