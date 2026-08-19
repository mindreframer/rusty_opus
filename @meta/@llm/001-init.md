Our task is to generate a Elixir / Rustler wrapper around the opus-rs library.

https://github.com/restsend/opus-rs

I want to be able to do some operation on opaus files like changing the quality of the encoding, yeah, maybe with a little bit more, but just don't over engineer it. Keep it reasonable.


our work is roadmap-driven.

here is an example:
/Users/roman/Desktop/work/prj.ideas/MAGICLOG/corrosionex

here is another library: 
/Users/roman/Desktop/work/prj.ideas/ELIXIR_CLUSTER/ex_rocket

Important is the fact that we have tools to actually guide the agent properly through a complete implementation of such a roadmap.
That means the agent will properly set up the roadmap. It will create the corresponding files, like the script to execute quality checks. It will create the corresponding agent MD file, it will create the README file with nice description and badges, and it will configure CI in a way that you see in my examples, and then we will create roadmaps that each contain 7 epics with 7 phases, and we will implement each of those phase sequential epic sequentially, one after another. We will do Git commits after each completed epic if the quality check is green and everything is nice. Then we will configure CI and make sure that this CI run properly finishes. Then we will complete the roadmap. After the full completion, we will push things to GitHub and monitor that everything is working okay, and CI is also actually validating everything, and that all the jobs are properly finishing. Then if everything is green and our precompiled binaries for each platform properly compiled and ready, we can run a release by tagging a Git commit in GitHub and we will push generated libraries to the release page so that the pre-compiled files are properly downloaded when the package is installed. And we will also add a pipeline that will do a smoke test if those external precompiled files are properly loadable into our library.

Okay, and this is done in self-management by the agent.
The thing the agent will not do is actually release the library. Okay, because this is not possible, but the rest, like pushing to GitHub, monitoring everything, making sure that text is for our code is formatted and properly compiling before committing anything, and we have really meaningful tests, this is important.

You can supply a few real Ogg Opus clips as fixtures (for example from a local
SQLite DB via `FIXTURE_OGG_DB` and `scripts/import_fixtures.sh`).

Please analyze everything and then create me a corresponding roadmap that really makes sure things are properly executed. Be smart and try to reuse as much as possible, but keep it as simple as possible, do not over-engineer.

Also, you will reuse the configuration patterns from mix.ex. You will reuse my name, you will reuse the profile git upfile, right? So take as much inspiration as you can. This is one of my many libraries, and they should all feel consistent and highly professional.