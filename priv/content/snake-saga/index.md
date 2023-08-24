title: Snake Saga - Building a Game with Redux Generators
published: true
description: In which we learn generators by using React, Redux and Redux Saga to build a clone of Snake
category: Technical
tags: 
 - react
 - redux
 - redux-saga
 - frontend
image: /images/dock.avif
date: "2019-07-23"
slug: snake-saga
---
In the process of interviewing for front-end jobs, I've taken to building shorter-term projects that I can complete in the space of a weekend, both to practice writing accessible HTML/CSS and to discover new features of JavaScript. One of the more interesting projects I took on recently involved building a game of Snake in React — and not only because it was the first "video game" I've built.

This project was particularly interesting to me because it introduced one of the most unique JavaScript features I've come across in the last year: generators. Specifically, because I needed to take action each time the snake moved, I did some research on the major side-effect libraries available in the Redux ecosystem.

My thinking was that the snake's movement was the "main event", and all potential actions arising out of its movement (eating fruit, losing the game, etc.) should be handled immediately after arriving at each new square. My strategy, then, was to write the post-movement logic into side effects that had access to all game information and could either update the game, stop it altogether, or allow it to continue if no noteworthy events had occurred.

I've used Redux Thunk in the past, and I believe I could have written my side effect logic in Redux Thunk without too many headaches. However, because the point of these side projects was to learn new skills, and because the generator model of Redux Saga seemed to offer more flexibility if I could overcome the initial learning curve, the library seemed a natural choice.

Plus, who doesn't like the idea of their code going on a saga? Picture tiny snakes sailing on a longboat with Viking hats and tell me that doesn't bring a smile to your face. Wait, scratch that. Writing it out, I now realize that seafaring snakes are actually terrifying. Moving on...

Before diving into things, if you just want to see the code, check out the project repo here: [https://github.com/mariowhowrites/react-snake](https://github.com/mariowhowrites/react-snake). Keep in mind that this was a weekend project and not a production assignment. Notably, there are some performance and styling issues I'd clean up if ever I were to ship this game — not to mention some tests I'd need to write.

## Generators: A Quick Overview

The most straightforward explanation for generators that I've seen is that they're functions that your program can start and stop at will. Calling a normal function typically gives you no control over how and when the function runs. Your program simply runs the function and rolls with it until it either returns a value or throws an error. If the function triggers an infinite loop, your program is stuck waiting for an exit like the poor passengers of [Mr Bones' Wild Ride](https://knowyourmeme.com/memes/mr-bones-wild-ride) (safe for work, Rollercoaster Tycoon content).

Generators work differently by giving execution control to the program itself. Put another way, think of generators as loops that your program can increment on its own time. Given the following code:

```js
// the '*' marks this function as a generator
function* loopSayings() {
  yield "hello"
  yield "goodbye"
}
```

Callling `loopSayings()` for the first time would start the generator. In order to work with it further, you'd want to save the generator as a variable, such as `const loopGenerator = loopSayings()`.

From there, your program can control the generator by calling `loopGenerator.next()`. Each time the method `next()` is called, the generator will advance to the following `yield` statement in the function.

Whenever a `yield` statement is encountered, the generator stops executing and returns an object with two properties:

- `value` will return whatever's to the right of the `yield` statement where the generator stopped
- `done` is a boolean value indicating whether the generator has reached the final `yield` statement or not. Further calls to `next()` after this point will give a `value` of undefined.

Therefore, after starting the generator for the first time, `loopGenerator.next().value` would return 'hello'. Calling `loopGenerator.next().value` again would return the value 'goodbye', at which point the `done` property would be true and all future `next()` calls would return undefined values.

Putting this all together, sample usage of a generator could look like this:

```js
function* loopSayings() {
  yield "hello"
  yield "goodbye"
}

const loopGenerator = loopSayings() // starts the generator
console.log(loopGenerator.next().value) // 'hello'
console.log(loopGenerator.next().value) // 'goodbye'
console.log(loopGenerator.next().value) // undefined, generator has finished
```

## Generators in Redux Saga

So now that we've got a basic understanding of how generators work, let's see how this pattern is applied within the Redux Saga library. Let's start from the obvious: Redux Saga is a library built on top of the Redux state management library, which itself is the most popular tool to manage complex state in React applications.

Specifically, Redux Saga works primarily as Redux **middleware.** For the uninitiated, middleware is essentially a fancy term for any logic that works in the middle of a given process.

For example, if we were building a web server, we could write middleware that determines whether a given user can access a specific resource. This middleware would happen in the middle of the request, after the user has made the request and before our server begins fetching the resource. If the user isn't able to access the given resource — if they're not logged in, for example, or if they're asking to access protected data that belongs to another user — this middleware can stop the request immediately, saving your application from potentially exposing sensitive information.

Applying this model to Redux, all middleware is run **after** receiving a request to update state, but **before** your reducers have actually updated to reflect the new state. This gives middleware the ability to change incoming state requests before they hit your reducers, offering a powerful method of customizing your Redux logic based on external events.

In the case of Redux Saga, because the library primarily deals with side effects, we won't be altering state requests directly. However, Redux Saga takes full advantage of the fact that middleware can see not only incoming actions, but also the present state of your reducers at the time that the action is dispatched. In the case of our Snake game, this setup allows us to combine the current board state with the action being dispatched to figure out what action should be taken.

Put another way, in my experience Redux Saga provides an excellent parallel to listeners or observers in other languages and frameworks. They observe external events and potentially trigger new actions in response to observed events.

## Sagas in Practice

So far, this description has been pretty abstract — let's ground it with some actual Snake code. In my Snake implementation, I've set up the board as a square grid of blocks. In my Redux library, I keep track of which blocks represent walls, fruit, open spaces, and the snake itself. Once per tick, the snake moves forward one block and the new position is dispatched as a Redux action.

In my case, I wrote four different sagas to listen to various events occurring across the game board:

```js
import { all } from "redux-saga/effects"

import watchPosition from "./watchPosition"
import watchFruitCollection from "./watchFruitCollection"
import { watchGameStart, watchGameEnd } from "./watchGameChange"

export default function* rootSaga() {
  yield all([
    watchPosition(),
    watchFruitCollection(),
    watchGameStart(),
    watchGameEnd(),
  ])
}
```

The `all()` method accepts a group of sagas and combines them into one middleware, which is attached to the Redux store shortly before loading the main application.

Let's look at the fruit collection saga, which fires whenever a new fruit has been collected:

```js
import { takeEvery, put, select } from "redux-saga/effects"

import * as types from "../store/types"
import { makeFruit } from "../utils"

export default function* watchFruitCollection() {
  yield takeEvery(types.FRUIT_COLLECT, handleFruitCollection)
}

function* handleFruitCollection({ payload }) {
  const size = yield select(state => state.game.size)
  yield put({ type: types.FRUIT_ADD, payload: [makeFruit(size)] })
  yield put({ type: types.ADD_SCORE })
}
```

Notice that the saga itself contains only one line of code, starting with the `takeEvery` call. This function tells Redux Saga to "take" every action with the type `FRUIT_COLLECT` and pass the action to the `handleFruitCollection` method.

From there, because we know that the action is of type `FRUIT_COLLECT`, we know the snake has just collected a new fruit and we can dispatch actions accordingly. Namely, there are two actions that should be taken when a new fruit is collected:

1. The player score needs to be incremented by one.
2. A new fruit needs to be added to the game board.

To add a new fruit to the board, we first need to know how big our game board is so that we don't accidentally add a fruit where it shouldn't be — namely, in or beyond a wall. To get the board size, we first use the `select` function provided by Redux Saga to pull the `size` property from our `game` reducer. From there, we dispatch a new action `FRUIT_ADD` using a new fruit created by `makeFruit`, which returns a new fruit at a random valid position on the game board.

With that accomplished, the only thing left to do is to increment the current score. Instead of handling the state change within the saga, we dispatch a new action with type `ADD_SCORE`, which our `game` reducer will catch and use to update the player's score.

There are two important processes going on here:

1. All state modifications are relegated to reducers instead of being handled directly within the saga. This is an intentional design pattern — Redux Sagas are supposed to be side effects, not secondary reducers.
2. Our handler generator is not being called directly. Instead, the Redux Saga middleware is responsible for invoking our generators, which it does by walking through each saga until the `done` property from the generator returns `true`.

## Why Use Generators At All?

Because the generator process is handled in a synchronous manner by our Redux Saga middleware, you might be wondering why generators are used in this case at all. Wouldn't it be faster and more direct to include all of our state update logic within the reducer itself? What's to stop us from incrementing the player score and adding a new fruit within the `COLLECT_FRUIT` reducer and skipping Redux Saga entirely?

Whether or not Redux Saga is a good idea for your application is mostly a matter of scale. For a simpler project, it may have made sense to write out all of our Redux data mutations within the reducer function itself. However, more complex applications often require more separation between cause and effect than you could get by grouping all of your logic in the same file. By separating all of the "side effects" of an update from the update itself, we can keep our reducers straightforward and add additional side effects without changing our reducer code and opening ourselves to state-related bugs.

For a better example of this, let's look at the `watchPosition` saga in the Snake app:

```js
export default function* watchPosition() {
  yield takeEvery(types.CHANGE_POSITION, handlePositionChange)
}

const getState = state => ({
  fruitPositions: state.fruit.fruitPositions,
  snakeQueue: state.snake.snakeQueue,
  snake: state.snake.snake,
})

function* handlePositionChange({ payload: newPosition }) {
  const { fruitPositions, snakeQueue, snake } = yield select(getState)

  const gameIsOver = collidedWithSelf(snake, newPosition)

  if (gameIsOver) {
    yield put({ type: types.GAME_END })
    return
  }

  const fruitToRemove = findFruitToRemove(fruitPositions, newPosition)

  if (fruitToRemove >= 0) {
    yield put({ type: types.FRUIT_COLLECT, payload: fruitToRemove })
    yield put({ type: types.SNAKE_QUEUE, payload: newPosition })
  }

  if (snakeQueue.length >= 1) {
    yield put({ type: types.SNAKE_GROW })
  }
}
```

We see that `watchPosition` has a nearly identical structure to `watchFruitCollection` above. All actions of type `CHANGE_POSITION` are taken on a new saga led by the `handlePositionChange` generator.

From there, however, a more complex series of events takes place. Using helper methods, this generator checks on various game conditions, such as whether the snake has collided with itself or collected a fruit.

Would it make sense to handle the fruit collection logic within the position reducer? To me, the answer is no. By delegating all of the effect work to sagas, each of my reducer cases maxes out at around five lines of code. I can add as much functionality into this `watchPosition` generator as I want without needing to change the basic mechanics of how my snake moves across the board. And because `put` and `select` return simple JavaScript objects, all of this code can be easily tested by starting and iterating our sagas manually, much like we did with `loopSayings` in the intro to generators.
