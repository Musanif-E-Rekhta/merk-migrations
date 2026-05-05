use clap::{Parser, Subcommand};
use merk_migrations::{MigrationStatus, Migrator};
use surrealdb::Surreal;
use surrealdb::engine::any::Any;
use surrealdb::opt::auth::Root;

#[derive(Parser)]
#[command(name = "migrate", about = "SurrealDB migration runner")]
struct Cli {
    /// SurrealDB connection URL
    #[arg(long, env = "SURREAL_URL", default_value = "ws://localhost:8000")]
    url: String,

    /// Namespace
    #[arg(long, env = "SURREAL_NS")]
    ns: String,

    /// Database
    #[arg(long, env = "SURREAL_DB")]
    db: String,

    /// Root username
    #[arg(long, env = "SURREAL_USER", default_value = "root")]
    user: String,

    /// Root password
    #[arg(long, env = "SURREAL_PASS", default_value = "root")]
    pass: String,

    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// Apply pending migrations (all by default)
    Up {
        /// Number of migrations to apply
        #[arg(short, long)]
        steps: Option<u32>,
    },
    /// Roll back applied migrations (1 by default)
    Down {
        /// Number of migrations to roll back
        #[arg(short, long)]
        steps: Option<u32>,
    },
    /// Drop all tables and re-apply every migration
    Fresh,
    /// Roll back all migrations via down files, then re-apply all
    Refresh,
    /// Show applied / pending status for all migrations
    Status,
}

#[tokio::main]
async fn main() {
    dotenvy::from_filename(".env.local").ok();
    dotenvy::dotenv().ok();

    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::from_default_env()
                .add_directive("merk_migrations=info".parse().unwrap()),
        )
        .init();

    let cli = Cli::parse();

    if let Err(e) = run(cli).await {
        eprintln!("error: {e}");
        std::process::exit(1);
    }
}

async fn run(cli: Cli) -> anyhow::Result<()> {
    let db: Surreal<Any> = surrealdb::engine::any::connect(&cli.url).await?;
    db.signin(Root {
        username: cli.user,
        password: cli.pass,
    })
    .await?;
    db.use_ns(&cli.ns).use_db(&cli.db).await?;

    match cli.command {
        Command::Up { steps } => {
            Migrator::up(&db, steps).await?;
        }
        Command::Down { steps } => {
            Migrator::down(&db, steps).await?;
        }
        Command::Fresh => {
            Migrator::fresh(&db).await?;
        }
        Command::Refresh => {
            Migrator::refresh(&db).await?;
        }
        Command::Status => {
            let statuses = Migrator::status(&db).await?;
            print_status_table(&statuses);
        }
    }

    Ok(())
}

fn print_status_table(statuses: &[MigrationStatus]) {
    let name_width = statuses
        .iter()
        .map(|s| s.name.len())
        .max()
        .unwrap_or(4)
        .max(4);

    println!(
        " {:<8}  {:<5}  {:<width$}",
        "Status",
        "Batch",
        "Name",
        width = name_width
    );
    println!("{}", "─".repeat(name_width + 20));

    for s in statuses {
        let status = if s.applied { "applied" } else { "pending" };
        let batch = s
            .batch
            .map(|b| b.to_string())
            .unwrap_or_else(|| "-".to_string());
        println!(
            " {:<8}  {:<5}  {:<width$}",
            status,
            batch,
            s.name,
            width = name_width
        );
    }
}
