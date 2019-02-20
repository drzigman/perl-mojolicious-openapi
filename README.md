# Mojolicious API with OpenAPI 2.0/Swagger

This repo contains source code for a [presentation on OpenAPI 2.0 (Swagger)](https://scottw.github.io/presentations/perl-mojolicious-openapi/) and how to write an API for it using Mojolicious. This code is for demo purposes only. If you use this for any other reason, you should at least change the secret in the configuration file.

The "time tracker" model code in this repository comes from [another repo](https://github.com/scottw/perl-oo-time-tracker) which is used in [another presentation](https://scottw.github.io/presentations/perl-object-orientation/).

The rest of this document is a script I followed for the demo part of the presentation.

Some people like to edit their Swagger document in an online editor:

(visit https://editor.swagger.io and import `swagger.yaml`)

The nice thing about the online editor—and you can download this and run it locally by the way—is that it gives you immediate feedback when your specification has a syntax error.

Now we have a syntactically correct OpenAPI v2 document. Doing this kind of design work *before* you code it has a few significant advantages:

- now that we have a specification, it's easy for the UI to explore the shape of the API, see examples, and then to use it to generate their own mock server to develop against (generate server -> node.js, unzip it, npm install && npm start, etc.)
- you get beautiful documentation that managers just adore. It's also a nice reference for developers
- you gain empathy for the client—I can't tell you how many times I've written an API and then realized I had gotten the design all wrong later when I tried to use my API to do something useful. It's so easy to guess wrong about how the API will be used. Good API design doesn't just happen.

Ok, we're done with part 1. Part 2 is connecting this with our model.

Again, we're going to copy-paste most of this for the sake of time.

First I'm going to copy in the Mojolicious script. This is typically generated for you by `mojo generate app`. We'll also copy in the two mojolicious files and the test file.

(copy the files from *this* repo)

We'll look at these now. The entry point for all Mojolicious apps is the script file, but there's no user serviceable parts inside. As I mentioned, this script is created for you when you run `mojo generate app`.

(open `script/time_tracker`)

This is loading Mojolicious::Commands, which is the CLI interface for Mojolicious, and then runs `start_app` which when we give it `daemon` as an argument, starts a server listening on port 3000. `start_app` finally loads and compiles our application, whose root is here in the `lib` directory.

(open lib/Time/Tracker.pm)

This file's skeleton is also automatically generated by Mojolicious. I've removed most of that skeleton and added my own content. The Mojolicious web framework loads this file and looks for the `startup` method. Here we load plugins and define helpers and routes.

Let's walk through this file. What you see on the screen is the entire file.

Here we load Mojo's configuration plugin, which looks for a file whose name is the same as our app, in this case `time-tracker` with a `.conf` ending. If it finds it, it loads it (typically it's just a hash) and puts its keys and values in the application's namespace under `config`, so we can access it like this on the next line.

Let's look at the configuration file:

(open time-tracker.conf)

You can see that it's just a Perl hash reference. We can put whatever is convenient for us here. In this case, I've put the name of the ledger's storage class (`Ledger::File`) here and some constructor arguments for that class.

(back to `lib/Time/Tracker.pm`)

I'm just doing a little Poor Man's dependency injection here, but this is really one of the advantages of using a dynamic language like Perl, so why not take advantage of that? We are loading the appropriate storage class for our ledger.

Next we pull out any arguments for that ledger class from the config.

Here we create a "helper". In Mojolicious, you can create on-the-fly methods that are accessible from every controller. Here we want to expose a `tracker` object instance, but we don't want to create a new one every time because it's keeping state for us. This is a form of the singleton pattern.

Finally, we load the OpenAPI plugin and pass it some configuration of where to find our OpenAPI file. Mojolicious's OpenAPI plugin will parse the file—and it knows how to parse both Swagger (OpenAPI 2.0) and OpenAPI 3.0 files—validate the syntax, then for each "path" defined, it will extract the input and output validation information, and then define Mojolicious routes—URLs—that will direct incoming requests to the appropriate controller.

This connection between the path definition and which controller to invoke is done using the `x-mojo-to` Swagger extension.

Now let's take a glance at the controllers.

(open lib/Time/Tracker/Controller/Timers.pm)

This is the entire file. You can see that we load the Timer class. Then we define the `summary` controller. This is called from the OpenAPI plugin when the `GET /v1/timers/summary` route is hit:

(refer to `swagger.yaml`; look at `x-mojo-to: 'timers#summary'`)

This is one of the simplest controllers you'll see, but with OpenAPI, many of your controllers will be stupid simple like this because all of the input validation and output validation is handled by OpenAPI.

Here we validate the input, which if it fails, OpenAPI will return an error back to the client. If it succeeds, we get a controller object. In this controller, there is no input, so this isn't strictly needed, but it's good practice to leave there in case we add query parameters someday. Then we get a handle to that tracker helper we defined at startup and we invoke its summary method, which returns a hash reference.

That hash reference is automatically converted into a JSON object, serialized, and then passed to the OpenAPI plugin for output validation. That is, OpenAPI not only insures that the input to your controllers is validated, but also the output from your controllers is validated. If you break your contract with the client, the plugin will let you know with a friendly 500 error.

The second controller here is `append`. We validate the input—if it fails validation, we return a 400 error to the client. Otherwise, we move on and extract that input through the `validation` object—we know the attribute is called 'timer' because that's what our spec says it's called:

(look at swagger.yaml: ` parameters: - name: timer`)

We create a new Timer object from the input data—we should add some error checking here, by the way, just so you know. We append this new Timer object to the tracker's ledger, then we render a message. Let's start up the server now:

[terminal 1: `script/time_tracker daemon`]

[terminal 2:]

```sh
curl -X GET http://localhost:3000/v1/timers/summary

curl -X POST -H 'Content-Type: application/json' http://localhost:3000/v1/timers -d '{"start":500,"stop":1000,"activity":"meeting"}'

curl -X POST -H 'Content-Type: application/json' http://localhost:3000/v1/timers -d '{"start":1000,"stop":2000,"activity":"working"}'

curl -X GET http://localhost:3000/v1/timers/summary
```

So that's it. Now we have our server working, we can start to integrate with the UI. Because we were working off of the same specification, it's unlikely we'll have any impedance mismatch.

The Mojolicious OpenAPI plugin is fantastic and we get so much benefit for so little work.
