title: Web Scraping with Puppeteer + Laravel Sail
published: true
description: Using Puppeteer, Docker, Headless Chrome and Laravel Sail to automate repetitive web-based tasks
image: /images/stickers.jpg
category: Technical
date: "2022-06-22"
slug: price-calculator-laravel-sail
---

In my experience, the one predictable aspect of working with freelance clients is that assumptions are dangerous things to make. 

To be clear, communication is crucial for any development work, freelance or not. Even in a job setting where you can expect technical literacy from your coworkers, clearly outlining expectations at the beginning of a new project can help differentiate you from the common programmer’s tendency to code first and ask questions later. 

However, going over project requirements with a new freelance client warrants an extra degree of caution, for two reasons:

1. In the overwhelming majority of cases, the client knows nothing about development. This isn’t a bad thing, obviously — you wouldn’t have been hired otherwise! But, this does mean you have an additional responsibility to fully understand what you’re building, as there’s nobody to tell you if your technical assumptions are wrong.
2. The client knows their business better than you ever will. While this is, in many ways, a tremendous asset to you, it’s important to know that expertise has its own pitfalls. Namely, things may be obvious to your client that you, as someone with little experience in their field, wouldn’t guess in a million years. Because it’s obvious to them, they may not stop to think the same isn’t obvious to you.

Such a case happened to me recently, when a local sticker shop approached me about building a calculator to help them price out custom orders. On its face, the job seemed simple; they already had a price calculator that they had been using for just this purpose. At first, the only problem seemed to be that some of the numbers this calculator was producing weren’t anywhere close to correct. There were some configurations where buying 1,000,000 stickers was the same price as buying a 1,000 — a great deal for customers, but a potentially ruinous one for my client’s business. 

Straightforward enough. Access the code, look into the database, find the error and fix it. 

That’s when I asked about where the existing calculator was hosted. Apparently, this calculator had been built by a business associate who later became a competitor. This competitor had left the original calculator up as a favor to my client, but didn’t feel particularly inclined to give us access to either the code or the numbers behind it. 

As you might imagine, this complicated matters somewhat. Not only did I need to build a new calculator from scratch, I also needed to somehow get all the relevant numbers from the original calculator, as well as figure out where these numbers went wrong.

Two of these processes — fixing the numbers and building the new calculator — were either too straightforward or too business-related to include in this dev post. Instead, this article focuses on the part that posed the most

## Scraping in Sail

Before I could build a new calculator, I needed to get the numbers from the existing calculator. This calculator was publicly accessible, so I didn’t need to hack any servers, but getting the numbers involved actually using the calculator. As I needed to cover every height and width from 1 inch to 24 inches in increments of 0.25 inches, as well as every quantity from 50 to 10,000, the programmer’s tendency towards laziness would have never allowed me to derive these numbers by hand. 

I needed to find a way to automate this process, and instinctively thought to use a web automation framework. Web automation, although primarily used for testing with Selenium as the most popular example, can also be used to navigate websites programmatically. If I could get such a framework to punch the relevant numbers into the calculator and return the results to my backend, that’d save me the hours it would have taken to use the calculator myself. 

From previous jobs, both salaried and freelance, I have some experience automating websites with Node’s [Puppeteer](https://pptr.dev/) library, so I decided to use that. I believe it would have been possible to accomplish the same task using Laravel’s existing support for Selenium, including the Selenium instance that comes with Laravel Sail by default. However, hacking around Laravel’s testing-focused infrastructure to have Selenium act as a web scraping tool felt a bit too brittle for my liking. Furthermore, as I knew that at some point I’d need to evaluate JavaScript on the headless browser to read values from the calculator’s HTML, I figured it would be more efficient to write the entire scraper script in JavaScript, rather than the JavaScript-within-PHP approach that working within the Laravel context would have required. 

This brought up my next issue — getting Puppeteer’s headless browser to work within the Docker image provided by Laravel Sail. The first step, as one might imagine, was to install Puppeteer: `sail npm install puppeteer`. Just to test things out, I wrote the most basic scraper script imaginable and ran that to see if everything was working as expected. 

Reader, everything was not working as expected. 

The first error I encountered referred to a browser not existing. I ended up having to go into `node_modules/puppeteer` and running `npm install` in that directory to install the necessary browser. 

The second error read something along the lines of “libnss3 no such file”. This one was a bit more complicated, and I ended up following most of the instructions on [this StackOverflow answer](https://stackoverflow.com/questions/66214552/tmp-chromium-error-while-loading-shared-libraries-libnss3-so-cannot-open-sha). From the answer, it seemed that I needed to install some dependencies into my Docker image to get things working as expected. However, as I didn’t have access to the Docker image, I first needed to publish Sail’s Docker config with `sail artisan sail:publish`. This allowed me to add a line to the Dockerfile below the existing image setup to add all the dependencies necessary for Puppeteer to work.

The third error was what truly threw a wrench in my plans. Even though my browser was now running as expected, I couldn’t get my scraper to start because the browser I had installed did not come with a sandbox. After doing a bit of research into what [browser sandboxing](https://www.browserstack.com/guide/what-is-browser-sandboxing) was, I learned that I could circumvent this error by adding a `--no-sandbox` flag to the method launching Puppeteer in my script. 

At last, my script was running! But, as mentioned, the sandbox error wasn’t in the rearview quite yet. Not running a sandbox in my browser meant that I couldn’t trust this scraper to run on any site I didn’t 100% trust. If you’ll remember, I didn’t have access to the code behind the existing calculator. Even though this site had been working for me without issue thus far, I couldn’t guarantee that it’d remain this way going forward.

Running a sandboxed browser within the Laravel image seemed fairly involved, if it was possible at all. Most answers I saw on the issue said simply to leave the `--no-sandbox` flag enabled, which I had already decided wasn’t a viable option in this case. 

It was here that I decided to alter my approach. Until now, I had been trying to get the headless browser working in the same service as my Laravel application. What if I ran the headless browser in its own service instead? Within the `docker-compose.yml` that comes with Sail, there are multiple services included by default, all of which can connect to each other via a shared internal network. If I could get the headless browser running on this network as its own service, I could overcome two flaws of my current approach:

1. Using a dedicated service for my browser would almost certainly mean I could run my browser with the proper sandbox; and
2. I could remove some of the extraneous setup I had added to the Laravel `Dockerfile`, thus reducing the chances of those dependencies causing hiccups down the line. 

It didn’t take long for me to find exactly what I needed: [browserless/chrome](https://hub.docker.com/r/browserless/chrome). Adding this to my Dockerfile was even simpler than I had imagined:

```jsx
chrome:
        image: 'browserless/chrome'
        ports: 
            - '${BROWSERLESS_CHROME_PORT:-3000}:3000'
        networks:
            - sail
        environment:
            - CONNECTION_TIMEOUT=-1
```

The only change I made that doesn’t follow the same pattern as the other services included with Sail by default is the `CONNECTION_TIMEOUT=-1`. This line was necessary to get my script working as intended because, by default, any connections to `headless/chrome` time out after 30 seconds, and my script ran… quite a bit longer than that.

Using a neat trick of `docker-compose` services, where any service in a network is accessible from any other service using that service’s name, connecting to my new `headless/chrome` instance was as simple as running:

```jsx
const browser = await puppeteer.connect({
        browserWSEndpoint: "ws://chrome:3000",
});
```

Much better! Not only did this browser run with a sandbox, I could also return the included `Dockerfile` to its original state.

With the proper browser setup configured, writing the script itself was fairly straightforward. My scraping function ended up looking like this:

```jsx
const getPrice = async (height, width, quantity, variant) => {
        await page.evaluate((_variant) => {
            document.documentElement
                .querySelector(`[value="${_variant}"]`)
                .click();
        }, variant);

        await page.evaluate(() => {
            document.documentElement
                .querySelector("input#product-custom-size")
                .click();
        });

        await page.select("select#cus_width", String(height));
        await page.select("select#cus_height", String(width));

        await page.evaluate(() => {
            document.documentElement
                .querySelector("input#product-custom-qty")
                .click();
        });

        await page.evaluate(() => {
            document.documentElement.querySelector("#Quantity").value = "";
        });

        await page.type("#Quantity", String(quantity));

        const price = await page.evaluate(
            () => document.documentElement.querySelector("#price").innerText
        );

        return {
            width,
            height,
            quantity,
            variant,
            price,
        };
    };
```

Basically, this script: 

- clicks on the select variant;
- clicks on the “custom dimensions” and “custom quantity” buttons;
- resets whatever values currently existed in these inputs (from previous iterations);
- inputs the selected height, width and quantity; and
- reads and saves the resultant price.

This script worked, with one major issue — at over 150,000 total entries, the resulting array was just too darn big. Trying to post this to my backend as-is resulted in in `413 - Payload Too Large` error. To solve this, I decided to do two things:

1. Create two data structures: PriceSnapshot and PriceMeasurement. A PriceSnapshot represented one total run of the scraper, while a PriceMeasurement represented one measurement captured during the snapshot.
2. Begin the script by creating one PriceSnapshot, then including this PriceSnapshot with a new request to a PriceMeasurement POST route whenever I had 10 or more PriceMeasurements in the queue.

The whole script looked something like this:

```jsx
require("dotenv").config();

const axios = require("axios").default;
const puppeteer = require("puppeteer");

let allPrices = [];
const CALCULATOR_URL = process.env.CALCULATOR_URL;

const VARIANTS = [
    "Gloss Laminated",
    "Gloss-Vinyl",
    "Clear Laminated",
    "Chrome",
];

(async () => {
    const { data: snapshotID } = await axios.post(
        "http://pricecalculator.test/api/price-snapshots",
        {
            url: CALCULATOR_URL,
        }
    );

    const browser = await puppeteer.connect({
        browserWSEndpoint: "ws://chrome:3000",
    });
    const page = await browser.newPage();
    await page.goto(CALCULATOR_URL);
    await page.waitForSelector("input#product-custom-size");

    const getPrice = async (height, width, quantity, variant) => {
        await page.evaluate((_variant) => {
            document.documentElement
                .querySelector(`[value="${_variant}"]`)
                .click();
        }, variant);

        await page.evaluate(() => {
            document.documentElement
                .querySelector("input#product-custom-size")
                .click();
        });

        await page.select("select#cus_width", String(height));
        await page.select("select#cus_height", String(width));

        await page.evaluate(() => {
            document.documentElement
                .querySelector("input#product-custom-qty")
                .click();
        });

        await page.evaluate(() => {
            document.documentElement.querySelector("#Quantity").value = "";
        });

        await page.type("#Quantity", String(quantity));

        const price = await page.evaluate(
            () => document.documentElement.querySelector("#price").innerText
        );

        return {
            width,
            height,
            quantity,
            variant,
            price,
        };
    };

    for (let variantIndex = 0; variantIndex < VARIANTS.length; variantIndex++) {
        for (
            let measurement = 1;
            measurement <= 24;
            measurement = measurement + 0.25
        ) {
            for (
                let quantity = 100;
                quantity <= 20000;
                quantity = quantity + 50
            ) {
                allPrices.push(
                    await getPrice(
                        measurement,
                        measurement,
                        quantity,
                        VARIANTS[variantIndex]
                    )
                );

                if (allPrices.length >= 10) {
                    await axios.post(
                        "http://pricecalculator.test/api/price-measurements",
                        {
                            prices: allPrices,
                            snapshotID,
                        }
                    );

                    allPrices = [];
                }
            }
        }
    }

    await browser.close();
})();
```

Notice how I used a similar trick to connect to my Laravel backend as I did to connect to the headless browser. Because I renamed my Laravel service from `laravel.test` to `pricecalculator.test`, I could connect to my app from my scraper by accessing pricecalculator.test. 

With one VERY IMPORTANT CAVEAT! I wish this were documented in the Laravel docs, but for some reason my PR adding this detail was closed, so I’ll include it here. 

If you change the service name in your `docker-compose.yml`  file, as I did by changing to `pricecalculator.test`, you MUST also add a corresponding variable to your .env file:

```bash
APP_SERVICE=pricecalculator.test
```

And that’s it! If there’s interest, I can write a follow-up post about the Livewire integration, but that part was far more by-the-book. Hope this helps anyone who’s looking to include some custom services to their Laravel Sail setups.