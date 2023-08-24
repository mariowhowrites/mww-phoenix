title: Parsing Open Source - Tailwind CSS Chapter 2
published: true
description: Continuing our journey into Tailwind by resolving config
tags:
 - tailwindcss 
 - javascript
 - nodejs
 - postcss
image: /images/cogs.jpg
category: Technical
date: "2019-04-19"
slug: parsing-tailwind-css-part-2
---

Welcome back! Firstly, I want to thank you for the warm reception you gave Chapter 1 of Parsing Open Source. I'm back with Chapter 2, where we'll finish off our analysis of Tailwind CSS. This chapter gets into the hairier parts of Tailwind CSS, so I'll be moving a bit slower than I did in the last chapter so we can make extra-sure we have a solid grasp of what's happening. I'll be building on what we established in Chapter 1, so it'd be a good idea to either read the first parts of that chapter or have some pre-existing knowledge of how PostCSS works.

This chapter is dedicated exclusively to two things: 1) a brief overview of my parsing process and 2) an extended look at the `resolveConfig` function, a deceptively short function that nonetheless encapsulates many of the patterns and abstractions that define functional programming.

## Grokking Complex Code

You may be wondering how to start parsing code in the open source libraries you use. My strategies are admittedly pretty simple, but they've proven effective to me so far and they're what I used to write this chapter. I'm presenting them in brief here so that you can use them the next time you're struggling to understand some code.

### Use the Tests, Luke

One of the biggest helps to me in writing this chapter was Tailwind's well-written tests. Good tests are sometimes better than documentation in helping to understand a library, as they provide examples of the codebase as the author intends for it to be used.

Because Tailwind's most intricate functions all have unique tests, parsing each individual function boiled down to running a single test over and over again. Here's my battle-tested workflow:

1. Isolate the test I want to run with Jest's CLI. If I'm testing the `resolveConfig` function, I run `jest __tests__/resolveConfig.test.js` on my command line from the project root.
2. Isolate one particular test that encapsulates the functionality I'm examining. Typically I pick the most complex test I can find in the test suite and change the line saying `test('complex test here')` to `test.only('complex test here')`. Adding the `only` method tells Jest to only run that particular test.
3. Throw `console.log` statements everywhere.

You think I'm joking, but I'm not. Much as I hate to admit it, Node's debugger is too clunky for me. Setting aside the time it takes to get it set up and working with Jest, you have to add a `debugger` statement to your code, then run the `repl` command once your code hits the right place. All of that, just to give you the same output as you get from a `console.log`? No thank you. Someone please let me know if I'm missing something, but until then `console.log` is bae.

If I'm feeling particularly ambitious, I'll write the output to a log file I create using Node's filesystem module. But most of the time, `console.log` will get me where I want to go.

### Work From the Outside In

Ok, so we've got our `console.logs` ready to go. Now what?

This will likely sound obvious to the point of banality, but I work from the outside in. First I'll log a function's arguments at the moment it starts executing - what does everything look like at the beginning?

From there, find the first transformation that happens and `console.log` it. Then, compare the results to the results from the first log. What's changed between then and now? Upon understanding the first step, move to the second. Write down your results if it helps you, then repeat the same process at the next level. Take a moment to consider why the difference is as it is. Consider both what's happening at the code level and what the author's intention is in transforming the data in this way.

Eventually, with enough time and patience, what once looked daunting will seem manageable, even obvious.

Baby steps are the key here. I often comment out and rewrite code to get a `console.log` where I need it to go — adding brackets to turn single-line functions into multi-line functions, breaking chained functions into individual functions, and so on. Don't be afraid to change the code and see what happens; the undo shortcut is there for a reason. Worst comes to worst, delete the whole repo and clone it again from GitHub.

Those are my code parsing strategies in a nutshell. With those established, onwards to Tailwind!

## ResolveConfig

The first function we left untouched in Chapter 1 is the `resolveConfig` function. To refresh quickly from last chapter, the `resolveConfig` function is responsible for merging the user-provided configuration with the default configuration to create a final configuration object. It's called near the beginning of the Tailwind process, before any PostCSS plugins have been applied, and it's responsible for creating the settings that the rest of Tailwind will abide by when creating its final CSS output.

Here is the code for that function:

```js
export default function resolveConfig(configs) {
  return defaults(
    {
      theme: resolveFunctionKeys(
        mergeExtensions(defaults({}, ...map(configs, "theme")))
      ),
      variants: defaults({}, ...map(configs, "variants")),
    },
    ...configs
  )
}
```

We should first note that the `defaults` function called here is imported from Lodash. How this function operates is crucial in the config resolution process, so let's go over it briefly. Basically, what `defaults` does is take the first object passed to it (also called the **target**) and fills it in with every other object in its parameter list, which are called **sources**. The function moves through the sources from left to right and, importantly, does not redefine a property if it already exists in the target.

Let's look at a simple example:

```js
const firstSource = {
  author: "Ursula Le Guin",
}

const secondSource = {
  author: "Dan Brown",
  actor: "Daniel Day-Lewis"
}

const finalTarget = defaults({}, firstSource, secondSource)

// console.logging finalTarget would result in the following:
{
  author: "Ursula Le Guin",
  actor: "Daniel Day-Lewis"
}
```

Two steps happen when `defaults` is called:

1. The empty target object is filled with the first source object. Because there is no `author` in the target yet, the author is set to Ursula Le Guin.
2. The target is filled with the second source object. Because there is no `actor` in the target yet, the target's actor is set to Daniel Day-Lewis. However, because there is already an `author` set in the target from step 1, the target does not take on the second source's `author` property. Dan Brown is rightfully cast aside into the dustbin of authorship.

The reason why this is important will be clear in a moment. For now, looking back at the `resolveConfig` function we can see that `defaults` function is used to ensure that the `theme` and `variants` keys of our final config are resolved first. From there, all other configuration values are passed in from the configs passed to `resolveConfig`.

It is also important here to remember that `resolveConfig` accepts an array as its only parameter, in which the user config comes before the default config. This is important because, based on what we know about the `defaults` function, we now know that any properties defined in the user config will not be overwritten by properties in the default config. The user config and the default config can be understood as more intricate versions of `firstSource` and `secondSource` from our example above. Because our user config is our first source, nothing from our second source — the default config — will take precedence, instead deferring to the user's preferences.

Now, let's take another look at the `resolveConfig` function:

```js
export default function resolveConfig(configs) {
  return defaults(
    {
      theme: resolveFunctionKeys(
        mergeExtensions(defaults({}, ...map(configs, "theme")))
      ),
      variants: defaults({}, ...map(configs, "variants")),
    },
    ...configs
  )
}
```

What we want to focus on here is our target: the first argument to `defaults` that has theme and variant keys. Let's also use some more indentation to make things slightly easier to read:

```js
{
  theme:
    resolveFunctionKeys(
      mergeExtensions(
        defaults(
          {},
          ...map(configs, 'theme')
        )
      )
    ),
  variants:
    defaults(
      {},
      ...map(configs, 'variants')
    ),
},
```

Let's look at what's happening in the `theme` property first, as it's a tad more complex. Knowing that the JavaScript engine will execute this function from the inside out, the first thing we need to look at is the `defaults` call.

That code looks like this:

```js
defaults({}, ...map(configs, "theme"))
```

We see that an empty target object is filled with the `theme` key from each configuration. As before, the user configuration is filled first, then any keys left undefined by the users are filled in from the default config.

Using the strategies I outlined at the beginning of the chapter, I picked one test in the resolveConfig test suite to run repeatedly in my parsing process. That test looks like this:

```js
test.only('theme values in the extend section are lazily evaluated', () => {
  const userConfig = {
    theme: {
      colors: {
        red: 'red',
        green: 'green',
        blue: 'blue',
      },
      extend: {
        colors: {
          orange: 'orange',
        },
        borderColor: theme => ({
          foo: theme('colors.orange'),
          bar: theme('colors.red'),
        }),
      },
    },
  }

  const defaultConfig = {
    prefix: '-',
    important: false,
    separator: ':',
    theme: {
      colors: {
        cyan: 'cyan',
        magenta: 'magenta',
        yellow: 'yellow',
      },
      borderColor: theme => ({
        default: theme('colors.yellow', 'currentColor'),
        ...theme('colors'),
      }),
    },
    variants: {
      borderColor: ['responsive', 'hover', 'focus'],
    },
  }

  const result = resolveConfig([userConfig, defaultConfig])

/* expected result not immediately relevant and thus left out for brevity */
```

When running the above test and examining the result of the first `defaults` function call, the result looks something like this:

```js
{
  colors: {
    red: 'red',
    green: 'green',
    blue: 'blue'
  },
  extend: {
    colors: {
      orange: 'orange'
    },
    borderColor: [Function: borderColor]
  },
  borderColor: [Function: borderColor]
}
```

We see that any values defined in the user config override any values in the default config. Namely, the `colors` defined by default have been thrown out and replaced by the user-config `colors`. We also see that the `extends` key holds an extra color, orange, and an extra function that will define border colors.

Knowing that this result is then immediately passed to `mergeExtensions`, let's look at that function next:

```js
function mergeExtensions({ extend, ...theme }) {
  return mergeWith(theme, extend, (themeValue, extensions) => {
    if (!isFunction(themeValue) && !isFunction(extensions)) {
      return {
        ...themeValue,
        ...extensions,
      }
    }

    return resolveThemePath => {
      return {
        ...value(themeValue, resolveThemePath),
        ...value(extensions, resolveThemePath),
      }
    }
  })
}
```

This function is trickier than it might appear at first, so let's take it line-by-line.

First, let's look at the function parameters. We see that an object is accepted as the sole parameter, and that this object is broken down into two key components. The `extends` key is pulled directly from the passed-in object, and all other keys on the object are combined using the rest operator `...` into a single object called `theme`. So, taking our result above, the top-level `color` and `borderColors` keys would be combined into `theme`, while the `extends` key would be used as-is.

From there, another Lodash function is called: `mergeWith`. Personally, I'm not sold on the `mergeWith` name. I would likely call this method `customMerge` instead, as what it's doing is merging two objects together using a custom merge function. In other words, the function passed as the third argument to `mergeWith` is called on each key in the object passed in as the first argument.

In the context of our test object, this means that `mergeWith` will be called twice: once for `colors` and once for `borderColors`. For each key, the following process occurs:

1. Compare the key values in each object.
2. If neither value is a function, combine the values and return the result.
3. If either value is a function, return a function that calls both functions and returns the combined result.

Step 3 is a bit complicated, so we'll have to go over that in detail. For now, let's focus on Step 2, as there's a mechanic at play here that differs significantly from what we've seen before.

The difference has to do with the way the ellipsis operator `...` is used in JavaScript. There are two primary uses of the spread operator, both of which we've seen already. The first, as we just saw in the function parameter, is used to condense multiple values into a single value. In the above example, `colors` and `borderColors` were combined into a `theme` object using an ellipsis. This use of the ellipsis in this manner is called **rest syntax**, and it creates one object out of multiple values.

The ellipsis is also used to perform an operation that is essentially the exact opposite of rest syntax. In this use, one object or array is expanded into multiple values. This syntax is called **spread syntax**, and we see it in use when creating the return objects in `mergeExtensions`.

There is one important detail to note here. In short, using spread syntax works exactly opposite to Lodash's `defaults` function: if the second source defines a key that is also present in the first source, the second source will override the first.

To use our previous example:

```js
const firstSource = {
  author: "Ursula Le Guin",
}

const secondSource = {
  author: "Dan Brown",
  actor: "Daniel Day-Lewis"
}

const finalTarget = { ...firstSource, ...secondSource }

// console.logging finalTarget would result in the following:
{
  author: "Dan Brown", // secondSource overrides firstSource!
  actor: "Daniel Day-Lewis"
}
```

Sadly, Ursula Le Guin is pushed aside in this iteration to make room for a far less adept author. (I prefer Le Guin to Brown, if this hasn't been made clear.)

What this means in Tailwind context is that, given a key that exists in both the `theme` and the `extends` objects, the `extends` value will take precedence over the `theme` value.

In this way, the `extends` key can be useful in scenarios where you want to override one default value without replacing a given category entirely. For example, should you want to override the default red color without overriding all the default colors, to my understanding using the `extends` key would be a good way of doing so.

With a better understanding of how the rest and spread operators work, let's take another look at Step 3, which happens if either the theme or the extension is a function:

```js
function value(valueToResolve, ...args) {
  return isFunction(valueToResolve) ? valueToResolve(...args) : valueToResolve
}

mergeWith(theme, extend, (themeValue, extensions) => {
    // if themeValue or extensions is a function...
    return resolveThemePath => {
      return {
        ...value(themeValue, resolveThemePath),
        ...value(extensions, resolveThemePath),
      }
    }
  })
}
```

There are some similarities to Step 2 here: both steps construct an object using the spread operators on both the theme and extension values. However, in this case, instead of creating the object and returning it directly, a function is returned whose sole responsibility is to create the object.

This function accepts the `resolveThemePath` and passes it into the `value` function, which then determines whether either `themeValue` or `extensions` is itself an function. If so, it calls that function with `resolveThemePath`. The results of the two `value` calls are then merged and returned.

I know: lots of functions. This logic encapsulates both the power and the frustration that often accompany functional programming. While the ability to pass functions around and load them with relevant data as necessary is undoubtedly one of JavaScript's most powerful features, it can be maddeningly difficult to figure out exactly what is happening at what point. Where is a function being called and when it is simply being created for use elsewhere?

Notably, in the code above, no functions are actually invoked when merging theme and extension functions during `mergeExtensions`. Instead, a function is returned that calls `themeValue` and `extensions` at the same time.

Let's look at what's returned from `mergeExtensions` when calling our previous test:

```js
{
  colors: {
    red: 'red',
    green: 'green',
    blue: 'blue',
    orange: 'orange'
  },
  borderColor: [Function]
}
```

We can see two primary differences from the previous result:

1. The `colors` keys from the theme and extensions objects have been merged.
2. The two `borderColors` functions from the last result have been combined into one.

Additionally, we see that the `extends` key no longer exists, as it has been merged into the theme.

We've almost worked our way through the logic governing how the theme is constructed. Let's examine the final function, `resolveFunctionKeys`:

```js
function resolveFunctionKeys(object) {
  const resolveObjectPath = (key, defaultValue) => {
    const val = get(object, key, defaultValue)
    return isFunction(val) ? val(resolveObjectPath) : val
  }

  return Object.keys(object).reduce((resolved, key) => {
    return {
      ...resolved,
      [key]: isFunction(object[key])
        ? object[key](resolveObjectPath)
        : object[key],
    }
  }, {})
}
```

We see that a function expression `resolveObjectPath` is defined — let's return to that in a moment, once we understand the context in which its used. Let's instead look at what happens with the result of `mergeExtensions`:

1. `Object.keys` is used to create an array of the object's keys. For our above result, we'd get an array like this: `[colors, borderColors]`.
2. We loop through the array of keys using the `reduce` function. I'd definitely recommend doing some research on `reduce` if you're not familiar, because it's quite useful in a number of situations. For now, suffice it to say that `reduce` loops over an array in order to "build" a result. It's essentially a more flexible version of `map`.
3. For each key, we look at the assorted value. If it's a function, it's invoked using the `resolveObjectPath` function. If it's not a function, it's returned as-is.
4. The result is added to our "built" object. This "built" object is then passed along to the next key in the array.

In essence, this process converts the object from `mergeExtensions` into a raw JavaScript object, with all functions replaced by key-value pairs.

With this in mind, let's look at `resolveObjectPath`:

```js
function resolveFunctionKeys(object) {
  const resolveObjectPath = (key, defaultValue) => {
    const val = get(object, key, defaultValue)
    return isFunction(val) ? val(resolveObjectPath) : val
  }

  // rest of function here
}
```

The `resolveObjectPath` function uses a pattern we've seen before: the use of function expression to embed state into a function. In this case, the function takes in a `key` and a `defaultValue`, and uses the `object` passed into the top-level `resolveFunctionKeys` function to get the value from the object, using the default value if the config doesn't contain the value in question. If the returned value is a function, the process is repeated with the new function, otherwise the value is returned as-is.

At this point, my head is starting to spin a bit. I've written the word "function" so many times it's starting to lose all meaning. So let's ground what we're doing in some actual usage: what happens when we pass a function into our config?

Let's go back to the test we've been working with, deleting parts that aren't relevant:

```js
test.only("theme values in the extend section are lazily evaluated", () => {
  const userConfig = {
    theme: {
      colors: {
        red: "red",
        green: "green",
        blue: "blue",
      },
      extend: {
        colors: {
          orange: "orange",
        },
        borderColor: theme => ({
          foo: theme("colors.orange"),
          bar: theme("colors.red"),
        }),
      },
    },
  }

  const defaultConfig = {
    theme: {
      colors: {
        cyan: "cyan",
        magenta: "magenta",
        yellow: "yellow",
      },
      borderColor: theme => ({
        default: theme("colors.yellow", "currentColor"),
        ...theme("colors"),
      }),
    },
  }

  const result = resolveConfig([userConfig, defaultConfig])

  expect(result).toEqual({
    theme: {
      colors: {
        orange: "orange",
        red: "red",
        green: "green",
        blue: "blue",
      },
      borderColor: {
        default: "currentColor",
        foo: "orange",
        bar: "red",
        orange: "orange",
        red: "red",
        green: "green",
        blue: "blue",
      },
    },
  })
})
```

The extra-important parts here are the two `borderColor` functions: the first in the `extends` key of the user config, and the second in the default config.

If we look at the result, we see that the results of both functions eventually make their way into the final `borderColor` property. In this case, `foo` and `bar` both resolve to the user-defined options of `orange` and `red`, respectively. However, because the `default` color references a `yellow` color that doesn't make it into the final config, the fallback default of `currentColor` is used instead.

Through this example, we get a better understanding of how functions work within the context of `resolveConfig`. Any functions within the `theme` key are passed in the final theme values after replacing defaults and merging extensions. Now, let's explore how exactly this process happens.

The first context in which we see functions come into play is within `mergeExtensions`. This is where the default functions and the extension functions are combined.

Let's rewrite this code in a more literal way, as if we were hard-coding the test case within Tailwind:

```js
function mergeExtensions() {
  // we are hard-coding arguments below rather than passing them in
  function userExtendsBorderColorFunction(theme) {
    // from user.theme.extend.borderColor
    return {
      foo: theme("colors.orange"),
      bar: theme("colors.red"),
    }
  }

  function defaultBorderColorFunction(theme) {
    // from default.theme.borderColor
    return {
      default: theme("colors.yellow", "currentColor"),
      ...theme("colors"),
    }
  }

  return function(resolveThemePath) {
    return {
      ...defaultBorderColorFunction(...resolveThemePath),
      ...userExtendsBorderColorFunction(...resolveThemePath),
    }
  }
}
```

With this more literal example, it is hopefully clearer what `mergeExtensions` does when it comes across a key with a function value. In this case, when `mergeExtensions` encounters the `borderColor` key and sees that its value is a function, it creates a new function that combines the default function with the function the user defined in the `extends` key. As before, any keys defined in the user config override keys found in the default config via spread syntax.

It bears repeating here that, as of now, neither `userExtendsBorderColorFunction` nor `defaultBorderColorFunction` have been called yet. This is an important distinction, as exactly when these functions are called is important. If our two functions were to be called within `mergeExtensions`, it is possible that they would be called using incorrect values. This is because, if the `mergeExtensions` function is still executing and has not yet finished its work, there are no guarantees that the config object has been populated with all of the user-defined extensions.

This is, incidentally, what is meant when the test is labeled: "theme values in the extend section are lazily evaluated". Laziness, which here means "waiting until other functions have finished" and not "binge-watching Parks and Recreation reruns on Netflix" ensures that when our functions finally do run, they work with the fully updated theme values.

So, we know that the function returned from our modified `mergeExtensions` key above is added to the `borderColor` key and combined with the other theme values in a unified theme object.

In a similar vein to the last code snippet, let's rewrite `resolveFunctionKeys` in a more literal way, substituting any abstracted values with literal values where possible:

```js
function resolveFunctionKeys(object) {
  const resolveObjectPath = (key, defaultValue) => {
    const val = get(object, key, defaultValue)
    return isFunction(val) ? val(resolveObjectPath) : val
  }

  return {
    borderColor: object.borderColor(resolveObjectPath),
  }
}
```

I've removed the `Object.keys` and `reduce` from our modified function to simplify things a bit.

At this point, we can start connecting the dots regarding how Tailwind resolves functions using the extended configuration object. The `mergeExtensions` function finalizes all the static values (colors, padding, etc.) and sets up all functions to be run once all other values have been resolved. `resolveFunctionKeys` then takes those finalized values, creates a function that uses Lodash's `get` function to fetch keys out of the merged object, and returns them for the user to use in any theme functions.

Put another way, the `resolveObjectPath` function in `resolveFunctionKeys` is the actual function that is passed into the following theme key:

```js
    borderColor: theme => ({ // theme === resolveObjectPath from resolveFunctionKeys
      foo: theme('colors.orange') // fetches colors.orange from merged theme object,
      bar: theme('colors.red', 'defaultColor') // fetches colors.red, with a default of defaultColor
    })
```

Because the theme config object is captured within `resolveObjectPath` using function expressions, it is automatically accessible to the end user within the passed-in function. All the user has to do is specify which key value they want, and optionally which default value to fall back upon if the key is not found.

Now, let's take another look at the `resolveConfig` function:

```js
export default function resolveConfig(configs) {
  return defaults(
    {
      theme: resolveFunctionKeys(
        mergeExtensions(defaults({}, ...map(configs, "theme")))
      ),
      variants: defaults({}, ...map(configs, "variants")),
    },
    ...configs
  )
}
```

With any luck, this function is beginning to make a bit more sense. Virtually all of the complicated logic involves combining the user-provided theme with the default theme. The variants are resolved shortly after via a simple Lodash `defaults` call. Once the theme and the variants have been resolved, all other keys defined in the configuration are added to the object via another `defaults` call, and the result is returned for use in the rest of Tailwind.

### Wrapping Up Resolving Config

We've gone over quite a bit, written the word "function" quite a lot, and generally taken a whirlwind tour of functional programming, JavaScript-style.

At a high level, let's recap the steps that `resolveConfig` takes to merge the user's configuration with the default values:

1. Copies the user theme values into an object, with all functions left untouched.
2. Copies all default theme values into user theme values, not overriding any user settings.
3. Merges all values in the user's `theme.extend` property into the theme object. Static values are concatenated, while functions on the same property are rolled into a single function for later use.
4. Using the static values obtained from the last step, calls all functions created during the last step and merges the result to create a finalized theme property.
5. Resolves the variants property by combining the user config with the default config.
6. Resolves all other keys through the same user → default precedence.

We saw that this process is accomplished using the same techniques we've seen throughout Tailwind so far, namely: functional programming, function expressions, and Lodash. We also explored rest and spread syntax in greater depth, comparing them against Lodash's `default` function and observing how both are used in conjuction to resolve user themes against the default theme settings.

The next chapter in this series will cover the PostCSS plugin chain. As always, if you have questions on what we've covered so far or suggestions on what open source library I should parse next, let me know. I'm available in the comments section or on Twitter @mariowhowrites. Until next time!
