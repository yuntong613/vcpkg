#include <vcpkg/base/delayed_init.h>
#include <vcpkg/base/json.h>
#include <vcpkg/base/jsonreader.h>
#include <vcpkg/base/system.debug.h>

#include <vcpkg/paragraphs.h>
#include <vcpkg/registries.h>
#include <vcpkg/sourceparagraph.h>
#include <vcpkg/vcpkgcmdarguments.h>
#include <vcpkg/vcpkgpaths.h>
#include <vcpkg/versiondeserializers.h>
#include <vcpkg/versiont.h>

#include <map>

namespace
{
    using namespace vcpkg;

    using Baseline = std::map<std::string, VersionT, std::less<>>;

    static fs::path port_versions_dir = fs::u8path("port_versions");

    // this class is an implementation detail of `BuiltinRegistryEntry`;
    // when `BuiltinRegistryEntry` is using a port versions file for a port,
    // it uses this as it's underlying type;
    // when `BuiltinRegistryEntry` is using a port tree, it uses the scfl
    struct GitRegistryEntry
    {
        explicit GitRegistryEntry(std::string&& port_name) : port_name(port_name) { }

        std::string port_name;

        // these two map port versions to git trees
        // these shall have the same size, and git_trees[i] shall be the git tree for port_versions[i]
        std::vector<VersionT> port_versions;
        std::vector<std::string> git_trees;
    };

    struct BuiltinRegistryEntry final : RegistryEntry
    {
        explicit BuiltinRegistryEntry(std::unique_ptr<GitRegistryEntry>&& entry)
            : git_entry(std::move(entry)), scfl(nullptr)
        {
        }
        explicit BuiltinRegistryEntry(std::unique_ptr<SourceControlFileLocation>&& scfl_)
            : git_entry(nullptr), scfl(std::move(scfl_)), scfl_version(scfl->to_versiont())
        {
        }

        View<VersionT> get_port_versions() const override
        {
            if (git_entry)
            {
                return git_entry->port_versions;
            }
            else
            {
                return {&scfl_version, 1};
            }
        }
        ExpectedS<fs::path> get_path_to_version(const VcpkgPaths&, const VersionT& version) const override;

        // exactly one of these two shall be null

        // if we find a versions.json, this shall be non-null and BuiltinRegistryEntry uses git_entry's implementation
        std::unique_ptr<GitRegistryEntry> git_entry;
        // otherwise, if we don't find a versions.json,
        // we fall back to just using the version in the ports directory, and this is the non-null one
        std::unique_ptr<SourceControlFileLocation> scfl;
        VersionT scfl_version; // this exists so that we can return a pointer to it
    };

    struct FilesystemRegistryEntry final : RegistryEntry
    {
        explicit FilesystemRegistryEntry(std::string&& port_name) : port_name(port_name) { }

        View<VersionT> get_port_versions() const override { return port_versions; }

        ExpectedS<fs::path> get_path_to_version(const VcpkgPaths& paths, const VersionT& version) const override;

        std::string port_name;

        // these two map port versions to paths
        // these shall have the same size, and paths[i] shall be the path for port_versions[i]
        std::vector<VersionT> port_versions;
        std::vector<fs::path> version_paths;
    };

    struct BuiltinRegistry final : RegistryImplementation
    {
        BuiltinRegistry(std::string&& baseline) : m_baseline_identifier(std::move(baseline)) { }

        std::unique_ptr<RegistryEntry> get_port_entry(const VcpkgPaths& paths, StringView port_name) const override;

        void get_all_port_names(std::vector<std::string>&, const VcpkgPaths&) const override;

        Optional<VersionT> get_baseline_version(const VcpkgPaths& paths, StringView port_name) const override;

        ~BuiltinRegistry() = default;

        std::string m_baseline_identifier;
        DelayedInit<Baseline> m_baseline;
    };

    struct FilesystemRegistry final : RegistryImplementation
    {
        FilesystemRegistry(fs::path&& path, std::string&& baseline)
            : m_path(std::move(path)), m_baseline_identifier(baseline)
        {
        }

        std::unique_ptr<RegistryEntry> get_port_entry(const VcpkgPaths&, StringView) const override;

        void get_all_port_names(std::vector<std::string>&, const VcpkgPaths&) const override;

        Optional<VersionT> get_baseline_version(const VcpkgPaths&, StringView) const override;

    private:
        fs::path m_path;
        std::string m_baseline_identifier;
        DelayedInit<Baseline> m_baseline;
    };

    ExpectedS<fs::path> get_git_baseline_json_path(const VcpkgPaths& paths, StringView baseline_commit_sha)
    {
        auto baseline_path = paths.git_checkout_baseline(paths.get_filesystem(), baseline_commit_sha);
        if (paths.get_filesystem().exists(baseline_path))
        {
            return std::move(baseline_path);
        }
        return {Strings::concat("Error: Baseline database file does not exist: ", fs::u8string(baseline_path)),
                expected_right_tag};
    }

    struct VersionDbEntry
    {
        VersionT version;
        Versions::Scheme scheme = Versions::Scheme::String;

        // only one of these may be non-empty
        std::string git_tree;
        fs::path path;
    };

    // VersionDbType::Git => VersionDbEntry.git_tree is filled
    // VersionDbType::Filesystem => VersionDbEntry.path is filled
    enum class VersionDbType
    {
        Git,
        Filesystem,
    };

    fs::path relative_path_to_versions(StringView port_name);
    ExpectedS<std::vector<VersionDbEntry>> load_versions_file(Files::Filesystem& fs,
                                                              VersionDbType vdb,
                                                              const fs::path& port_versions,
                                                              StringView port_name,
                                                              const fs::path& registry_root = {});

    // returns nullopt if the baseline is valid, but doesn't contain the specified baseline,
    // or (equivalently) if the baseline does not exist.
    ExpectedS<Optional<Baseline>> parse_baseline_versions(StringView contents, StringView baseline);
    ExpectedS<Optional<Baseline>> load_baseline_versions(const VcpkgPaths& paths,
                                                         const fs::path& path_to_baseline,
                                                         StringView identifier = {});

    void load_all_port_names_from_port_versions(std::vector<std::string>& out,
                                                const VcpkgPaths& paths,
                                                const fs::path& port_versions_path)
    {
        for (auto super_directory : fs::directory_iterator(port_versions_path))
        {
            if (!fs::is_directory(paths.get_filesystem().status(VCPKG_LINE_INFO, super_directory))) continue;

            for (auto file : fs::directory_iterator(super_directory))
            {
                auto filename = fs::u8string(file.path().filename());
                if (!Strings::ends_with(filename, ".json")) continue;

                auto port_name = filename.substr(0, filename.size() - 5);
                if (!Json::PackageNameDeserializer::is_package_name(port_name))
                {
                    Checks::exit_with_message(
                        VCPKG_LINE_INFO, "Error: found invalid port version file name: `%s`.", fs::u8string(file));
                }
                out.push_back(std::move(port_name));
            }
        }
    }

    // { RegistryImplementation

    // { BuiltinRegistry::RegistryImplementation
    std::unique_ptr<RegistryEntry> BuiltinRegistry::get_port_entry(const VcpkgPaths& paths, StringView port_name) const
    {
        auto versions_path = paths.builtin_port_versions / relative_path_to_versions(port_name);
        if (paths.get_feature_flags().registries && paths.get_filesystem().exists(versions_path))
        {
            auto maybe_version_entries =
                load_versions_file(paths.get_filesystem(), VersionDbType::Git, paths.builtin_port_versions, port_name);
            Checks::check_exit(
                VCPKG_LINE_INFO, maybe_version_entries.has_value(), "Error: %s", maybe_version_entries.error());
            auto version_entries = std::move(maybe_version_entries).value_or_exit(VCPKG_LINE_INFO);

            auto res =
                std::make_unique<BuiltinRegistryEntry>(std::make_unique<GitRegistryEntry>(port_name.to_string()));
            auto gre = res->git_entry.get();
            for (auto&& version_entry : version_entries)
            {
                gre->port_versions.push_back(version_entry.version);
                gre->git_trees.push_back(version_entry.git_tree);
            }
            return res;
        }

        // Fall back to current available version
        auto port_directory = paths.builtin_ports_directory() / fs::u8path(port_name);
        if (paths.get_filesystem().exists(port_directory))
        {
            auto found_scf = Paragraphs::try_load_port(paths.get_filesystem(), port_directory);
            if (auto scfp = found_scf.get())
            {
                auto& scf = *scfp;
                auto maybe_error = scf->check_against_feature_flags(port_directory, paths.get_feature_flags());
                if (maybe_error)
                {
                    Checks::exit_with_message(VCPKG_LINE_INFO, "Parsing manifest failed: %s", *maybe_error.get());
                }

                if (scf->core_paragraph->name == port_name)
                {
                    return std::make_unique<BuiltinRegistryEntry>(
                        std::make_unique<SourceControlFileLocation>(std::move(scf), std::move(port_directory)));
                }
                Checks::exit_with_message(VCPKG_LINE_INFO,
                                          "Error: Failed to load port from %s: names did not match: '%s' != '%s'",
                                          fs::u8string(port_directory),
                                          port_name,
                                          scf->core_paragraph->name);
            }
        }

        return nullptr;
    }

    Baseline parse_builtin_baseline(const VcpkgPaths& paths, StringView baseline_identifier)
    {
        auto path_to_baseline = paths.builtin_port_versions / fs::u8path("baseline.json");
        auto res_baseline = load_baseline_versions(paths, path_to_baseline, baseline_identifier);

        if (!res_baseline.has_value())
        {
            Checks::exit_with_message(VCPKG_LINE_INFO, res_baseline.error());
        }
        auto opt_baseline = res_baseline.get();
        if (auto p = opt_baseline->get())
        {
            return std::move(*p);
        }

        if (baseline_identifier.size() == 0)
        {
            return {};
        }

        if (baseline_identifier == "default")
        {
            Checks::exit_with_message(VCPKG_LINE_INFO,
                                      "Couldn't find explicitly specified baseline `\"default\"` in the baseline file.",
                                      baseline_identifier);
        }

        // attempt to check out the baseline:
        auto maybe_path = get_git_baseline_json_path(paths, baseline_identifier);
        if (!maybe_path.has_value())
        {
            Checks::exit_with_message(VCPKG_LINE_INFO,
                                      "Couldn't find explicitly specified baseline `\"%s\"` in the baseline file, "
                                      "and there was no baseline at that commit or the commit didn't exist.\n%s",
                                      baseline_identifier,
                                      maybe_path.error());
        }

        res_baseline = load_baseline_versions(paths, *maybe_path.get());
        if (!res_baseline.has_value())
        {
            Checks::exit_with_message(VCPKG_LINE_INFO, res_baseline.error());
        }
        opt_baseline = res_baseline.get();
        if (auto p = opt_baseline->get())
        {
            return std::move(*p);
        }

        Checks::exit_with_message(VCPKG_LINE_INFO,
                                  "Couldn't find explicitly specified baseline `\"%s\"` in the baseline "
                                  "file, and the `\"default\"` baseline does not exist at that commit.",
                                  baseline_identifier);
    }
    Optional<VersionT> BuiltinRegistry::get_baseline_version(const VcpkgPaths& paths, StringView port_name) const
    {
        if (paths.get_feature_flags().registries)
        {
            const auto& baseline = m_baseline.get(
                [this, &paths]() -> Baseline { return parse_builtin_baseline(paths, m_baseline_identifier); });

            auto it = baseline.find(port_name);
            if (it != baseline.end())
            {
                return it->second;
            }
        }

        // fall back to using the ports directory version
        auto maybe_scf =
            Paragraphs::try_load_port(paths.get_filesystem(), paths.builtin_ports_directory() / fs::u8path(port_name));
        if (auto pscf = maybe_scf.get())
        {
            auto& scf = *pscf;
            return scf->to_versiont();
        }
        Debug::print("Failed to load port `", port_name, "` from the ports tree: ", maybe_scf.error()->error, "\n");
        return nullopt;
    }

    void BuiltinRegistry::get_all_port_names(std::vector<std::string>& out, const VcpkgPaths& paths) const
    {
        if (paths.get_feature_flags().registries && paths.get_filesystem().exists(paths.builtin_port_versions))
        {
            load_all_port_names_from_port_versions(out, paths, paths.builtin_port_versions);
        }

        for (auto port_directory : fs::directory_iterator(paths.builtin_ports_directory()))
        {
            if (!fs::is_directory(paths.get_filesystem().status(VCPKG_LINE_INFO, port_directory))) continue;
            auto filename = fs::u8string(port_directory.path().filename());
            if (filename == ".DS_Store") continue;
            out.push_back(filename);
        }
    }
    // } BuiltinRegistry::RegistryImplementation

    // { FilesystemRegistry::RegistryImplementation
    Baseline parse_filesystem_baseline(const VcpkgPaths& paths, const fs::path& root, StringView baseline_identifier)
    {
        auto path_to_baseline = root / port_versions_dir / fs::u8path("baseline.json");
        auto res_baseline = load_baseline_versions(paths, path_to_baseline, baseline_identifier);
        if (auto opt_baseline = res_baseline.get())
        {
            if (auto p = opt_baseline->get())
            {
                return std::move(*p);
            }

            if (baseline_identifier.size() == 0)
            {
                return {};
            }

            Checks::exit_with_message(
                VCPKG_LINE_INFO,
                "Error: could not find explicitly specified baseline `\"%s\"` in baseline file `%s`.",
                baseline_identifier,
                fs::u8string(path_to_baseline));
        }

        Checks::exit_with_message(VCPKG_LINE_INFO, res_baseline.error());
    }
    Optional<VersionT> FilesystemRegistry::get_baseline_version(const VcpkgPaths& paths, StringView port_name) const
    {
        const auto& baseline = m_baseline.get(
            [this, &paths]() -> Baseline { return parse_filesystem_baseline(paths, m_path, m_baseline_identifier); });

        auto it = baseline.find(port_name);
        if (it != baseline.end())
        {
            return it->second;
        }
        else
        {
            return nullopt;
        }
    }

    std::unique_ptr<RegistryEntry> FilesystemRegistry::get_port_entry(const VcpkgPaths& paths,
                                                                      StringView port_name) const
    {
        auto maybe_version_entries = load_versions_file(
            paths.get_filesystem(), VersionDbType::Filesystem, m_path / port_versions_dir, port_name, m_path);
        Checks::check_exit(
            VCPKG_LINE_INFO, maybe_version_entries.has_value(), "Error: %s", maybe_version_entries.error());
        auto version_entries = std::move(maybe_version_entries).value_or_exit(VCPKG_LINE_INFO);

        auto res = std::make_unique<FilesystemRegistryEntry>(port_name.to_string());
        for (auto&& version_entry : version_entries)
        {
            res->port_versions.push_back(std::move(version_entry.version));
            res->version_paths.push_back(std::move(version_entry.path));
        }
        return res;
    }

    void FilesystemRegistry::get_all_port_names(std::vector<std::string>& out, const VcpkgPaths& paths) const
    {
        load_all_port_names_from_port_versions(out, paths, m_path / port_versions_dir);
    }
    // } FilesystemRegistry::RegistryImplementation

    // } RegistryImplementation

    // { RegistryEntry

    // { BuiltinRegistryEntry::RegistryEntry
    ExpectedS<fs::path> BuiltinRegistryEntry::get_path_to_version(const VcpkgPaths& paths,
                                                                  const VersionT& version) const
    {
        if (git_entry)
        {
            auto it = std::find(git_entry->port_versions.begin(), git_entry->port_versions.end(), version);
            if (it == git_entry->port_versions.end())
            {
                return Strings::concat(
                    "Error: No version entry for ", git_entry->port_name, " at version ", version, ".");
            }

            const auto& git_tree = git_entry->git_trees[it - git_entry->port_versions.begin()];
            return paths.git_checkout_port(paths.get_filesystem(), git_entry->port_name, git_tree);
        }

        if (scfl_version == version)
        {
            return scfl->source_location;
        }

        auto& name = scfl->source_control_file->core_paragraph->name;
        return Strings::format(
            "Error: no version entry for %s at version %s.\n"
            "We are currently using the version in the ports tree, since no %s.json was found in port_versions.",
            name,
            scfl->to_versiont().to_string(),
            name);
    }
    // } BuiltinRegistryEntry::RegistryEntry

    // { FilesystemRegistryEntry::RegistryEntry
    ExpectedS<fs::path> FilesystemRegistryEntry::get_path_to_version(const VcpkgPaths&, const VersionT& version) const
    {
        auto it = std::find(port_versions.begin(), port_versions.end(), version);
        if (it == port_versions.end())
        {
            return Strings::concat("Error: No version entry for ", port_name, " at version ", version, ".");
        }
        return version_paths[it - port_versions.begin()];
    }
    // } FilesystemRegistryEntry::RegistryEntry

    // } RegistryEntry
}

// deserializers
namespace
{
    using namespace vcpkg;

    struct BaselineDeserializer final : Json::IDeserializer<std::map<std::string, VersionT, std::less<>>>
    {
        StringView type_name() const override { return "a baseline object"; }

        Optional<type> visit_object(Json::Reader& r, const Json::Object& obj) override
        {
            std::map<std::string, VersionT, std::less<>> result;

            for (auto pr : obj)
            {
                const auto& version_value = pr.second;
                VersionT version;
                r.visit_in_key(version_value, pr.first, version, get_versiont_deserializer_instance());

                result.emplace(pr.first.to_string(), std::move(version));
            }

            return std::move(result);
        }

        static BaselineDeserializer instance;
    };
    BaselineDeserializer BaselineDeserializer::instance;

    struct VersionDbEntryDeserializer final : Json::IDeserializer<VersionDbEntry>
    {
        static constexpr StringLiteral GIT_TREE = "git-tree";
        static constexpr StringLiteral PATH = "path";

        StringView type_name() const override { return "a version database entry"; }
        View<StringView> valid_fields() const override
        {
            static const StringView u_git[] = {GIT_TREE};
            static const StringView u_path[] = {PATH};
            static const auto t_git = vcpkg::Util::Vectors::concat<StringView>(schemed_deserializer_fields(), u_git);
            static const auto t_path = vcpkg::Util::Vectors::concat<StringView>(schemed_deserializer_fields(), u_path);

            return type == VersionDbType::Git ? t_git : t_path;
        }

        Optional<VersionDbEntry> visit_object(Json::Reader& r, const Json::Object& obj) override
        {
            VersionDbEntry ret;

            auto schemed_version = visit_required_schemed_deserializer(type_name(), r, obj);
            ret.scheme = schemed_version.scheme;
            ret.version = std::move(schemed_version.versiont);

            static Json::StringDeserializer git_tree_deserializer("a git object SHA");
            static Json::StringDeserializer path_deserializer("a registry path");

            switch (type)
            {
                case VersionDbType::Git:
                {
                    r.required_object_field(type_name(), obj, GIT_TREE, ret.git_tree, git_tree_deserializer);
                    break;
                }
                case VersionDbType::Filesystem:
                {
                    std::string path_res;
                    r.required_object_field(type_name(), obj, PATH, path_res, path_deserializer);
                    fs::path p = fs::u8path(path_res);
                    if (p.is_absolute())
                    {
                        r.add_generic_error("a registry path",
                                            "A registry path may not be absolute, and must start with a `$` to mean "
                                            "the registry root; e.g., `$/foo/bar`.");
                        return ret;
                    }
                    else if (p.empty())
                    {
                        r.add_generic_error("a registry path", "A registry path must not be empty.");
                        return ret;
                    }

                    auto it = p.begin();
                    if (*it != "$")
                    {
                        r.add_generic_error(
                            "a registry path",
                            "A registry path must start with `$` to mean the registry root; e.g., `$/foo/bar`");
                    }

                    ret.path = registry_root;
                    ++it;
                    std::for_each(it, p.end(), [&r, &ret](const fs::path& p) {
                        if (p == "..")
                        {
                            r.add_generic_error("a registry path", "A registry path must not contain `..`.");
                        }
                        else
                        {
                            ret.path /= p;
                        }
                    });

                    break;
                }
            }

            return ret;
        }

        VersionDbEntryDeserializer(VersionDbType type, const fs::path& root) : type(type), registry_root(root) { }

        VersionDbType type;
        fs::path registry_root;
    };

    struct VersionDbEntryArrayDeserializer final : Json::IDeserializer<std::vector<VersionDbEntry>>
    {
        virtual StringView type_name() const override { return "an array of versions"; }

        virtual Optional<std::vector<VersionDbEntry>> visit_array(Json::Reader& r, const Json::Array& arr) override
        {
            return r.array_elements(arr, underlying);
        }

        VersionDbEntryArrayDeserializer(VersionDbType type, const fs::path& root) : underlying{type, root} { }

        VersionDbEntryDeserializer underlying;
    };

    struct RegistryImplDeserializer : Json::IDeserializer<std::unique_ptr<RegistryImplementation>>
    {
        constexpr static StringLiteral KIND = "kind";
        constexpr static StringLiteral BASELINE = "baseline";
        constexpr static StringLiteral PATH = "path";

        constexpr static StringLiteral KIND_BUILTIN = "builtin";
        constexpr static StringLiteral KIND_FILESYSTEM = "filesystem";

        virtual StringView type_name() const override { return "a registry"; }
        virtual View<StringView> valid_fields() const override;

        virtual Optional<std::unique_ptr<RegistryImplementation>> visit_null(Json::Reader&) override;
        virtual Optional<std::unique_ptr<RegistryImplementation>> visit_object(Json::Reader&,
                                                                               const Json::Object&) override;

        RegistryImplDeserializer(const fs::path& configuration_directory)
            : config_directory(configuration_directory) { }

        fs::path config_directory;
    };
    constexpr StringLiteral RegistryImplDeserializer::KIND;
    constexpr StringLiteral RegistryImplDeserializer::BASELINE;
    constexpr StringLiteral RegistryImplDeserializer::PATH;
    constexpr StringLiteral RegistryImplDeserializer::KIND_BUILTIN;
    constexpr StringLiteral RegistryImplDeserializer::KIND_FILESYSTEM;

    struct RegistryDeserializer final : Json::IDeserializer<Registry>
    {
        constexpr static StringLiteral PACKAGES = "packages";

        virtual StringView type_name() const override { return "a registry"; }
        virtual View<StringView> valid_fields() const override;

        virtual Optional<Registry> visit_object(Json::Reader&, const Json::Object&) override;

        explicit RegistryDeserializer(const fs::path& configuration_directory) : impl_des(configuration_directory) { }

        RegistryImplDeserializer impl_des;
    };
    constexpr StringLiteral RegistryDeserializer::PACKAGES;

    View<StringView> RegistryImplDeserializer::valid_fields() const
    {
        static const StringView t[] = {KIND, BASELINE, PATH};
        return t;
    }
    View<StringView> valid_builtin_fields()
    {
        static const StringView t[] = {
            RegistryImplDeserializer::KIND,
            RegistryImplDeserializer::BASELINE,
            RegistryDeserializer::PACKAGES,
        };
        return t;
    }
    View<StringView> valid_filesystem_fields()
    {
        static const StringView t[] = {
            RegistryImplDeserializer::KIND,
            RegistryImplDeserializer::BASELINE,
            RegistryImplDeserializer::PATH,
            RegistryDeserializer::PACKAGES,
        };
        return t;
    }

    Optional<std::unique_ptr<RegistryImplementation>> RegistryImplDeserializer::visit_null(Json::Reader&)
    {
        return nullptr;
    }

    Optional<std::unique_ptr<RegistryImplementation>> RegistryImplDeserializer::visit_object(Json::Reader& r,
                                                                                             const Json::Object& obj)
    {
        static Json::StringDeserializer kind_deserializer{"a registry implementation kind"};
        static Json::StringDeserializer baseline_deserializer{"a baseline"};
        std::string kind;
        std::string baseline;

        r.required_object_field(type_name(), obj, KIND, kind, kind_deserializer);
        r.optional_object_field(obj, BASELINE, baseline, baseline_deserializer);

        std::unique_ptr<RegistryImplementation> res;

        if (kind == KIND_BUILTIN)
        {
            r.check_for_unexpected_fields(obj, valid_builtin_fields(), "a builtin registry");
            res = std::make_unique<BuiltinRegistry>(std::move(baseline));
        }
        else if (kind == KIND_FILESYSTEM)
        {
            r.check_for_unexpected_fields(obj, valid_filesystem_fields(), "a filesystem registry");

            fs::path path;
            r.required_object_field("a filesystem registry", obj, PATH, path, Json::PathDeserializer::instance);

            res = std::make_unique<FilesystemRegistry>(config_directory / path, std::move(baseline));
        }
        else
        {
            StringLiteral valid_kinds[] = {KIND_BUILTIN, KIND_FILESYSTEM};
            r.add_generic_error(type_name(),
                                "Field \"kind\" did not have an expected value (expected one of: \"",
                                Strings::join("\", \"", valid_kinds),
                                "\", found \"",
                                kind,
                                "\").");
            return nullopt;
        }

        return std::move(res);
    }

    View<StringView> RegistryDeserializer::valid_fields() const
    {
        static const StringView t[] = {
            RegistryImplDeserializer::KIND,
            RegistryImplDeserializer::BASELINE,
            RegistryImplDeserializer::PATH,
            PACKAGES,
        };
        return t;
    }

    Optional<Registry> RegistryDeserializer::visit_object(Json::Reader& r, const Json::Object& obj)
    {
        auto impl = impl_des.visit_object(r, obj);

        if (!impl.has_value())
        {
            return nullopt;
        }

        static Json::ArrayDeserializer<Json::PackageNameDeserializer> package_names_deserializer{
            "an array of package names"};

        std::vector<std::string> packages;
        r.required_object_field(type_name(), obj, PACKAGES, packages, package_names_deserializer);

        return Registry{std::move(packages), std::move(impl).value_or_exit(VCPKG_LINE_INFO)};
    }

    fs::path relative_path_to_versions(StringView port_name)
    {
        auto port_filename = fs::u8path(port_name.to_string() + ".json");
        return fs::u8path({port_name.byte_at_index(0), '-'}) / port_filename;
    }

    ExpectedS<std::vector<VersionDbEntry>> load_versions_file(Files::Filesystem& fs,
                                                              VersionDbType type,
                                                              const fs::path& port_versions,
                                                              StringView port_name,
                                                              const fs::path& registry_root)
    {
        Checks::check_exit(VCPKG_LINE_INFO,
                           !(type == VersionDbType::Filesystem && registry_root.empty()),
                           "Bug in vcpkg; type should never = Filesystem when registry_root is empty.");

        auto versions_file_path = port_versions / relative_path_to_versions(port_name);

        if (!fs.exists(versions_file_path))
        {
            return Strings::format("Couldn't find the versions database file: %s", fs::u8string(versions_file_path));
        }

        auto maybe_contents = fs.read_contents(versions_file_path);
        if (!maybe_contents.has_value())
        {
            return Strings::format("Failed to load the versions database file %s: %s",
                                   fs::u8string(versions_file_path),
                                   maybe_contents.error().message());
        }

        auto maybe_versions_json = Json::parse(*maybe_contents.get());
        if (!maybe_versions_json.has_value())
        {
            return Strings::format(
                "Error: failed to parse versions file for `%s`: %s", port_name, maybe_versions_json.error()->format());
        }
        if (!maybe_versions_json.get()->first.is_object())
        {
            return Strings::format("Error: versions file for `%s` does not have a top level object.", port_name);
        }

        const auto& versions_object = maybe_versions_json.get()->first.object();
        auto maybe_versions_array = versions_object.get("versions");
        if (!maybe_versions_array || !maybe_versions_array->is_array())
        {
            return Strings::format("Error: versions file for `%s` does not contain a versions array.", port_name);
        }

        std::vector<VersionDbEntry> db_entries;
        VersionDbEntryArrayDeserializer deserializer{type, registry_root};
        // Avoid warning treated as error.
        if (maybe_versions_array != nullptr)
        {
            Json::Reader r;
            r.visit_in_key(*maybe_versions_array, "versions", db_entries, deserializer);
            if (!r.errors().empty())
            {
                return Strings::format(
                    "Error: failed to parse versions file for `%s`:\n%s", port_name, Strings::join("\n", r.errors()));
            }
        }
        return db_entries;
    }

    ExpectedS<Optional<Baseline>> parse_baseline_versions(StringView contents, StringView baseline)
    {
        auto maybe_value = Json::parse(contents);
        if (!maybe_value.has_value())
        {
            return Strings::format("Error: failed to parse baseline file: %s", maybe_value.error()->format());
        }

        auto& value = *maybe_value.get();

        if (!value.first.is_object())
        {
            return std::string("Error: baseline does not have a top-level object.");
        }

        auto real_baseline = baseline.size() == 0 ? "default" : baseline;

        const auto& obj = value.first.object();
        auto baseline_value = obj.get(real_baseline);
        if (!baseline_value)
        {
            return {nullopt, expected_left_tag};
        }

        Json::Reader r;
        std::map<std::string, VersionT, std::less<>> result;
        r.visit_in_key(*baseline_value, real_baseline, result, BaselineDeserializer::instance);
        if (r.errors().empty())
        {
            return {std::move(result), expected_left_tag};
        }
        else
        {
            Checks::exit_with_message(
                VCPKG_LINE_INFO, "Error: failed to parse baseline:\n%s", Strings::join("\n", r.errors()));
        }
    }

    ExpectedS<Optional<Baseline>> load_baseline_versions(const VcpkgPaths& paths,
                                                         const fs::path& path_to_baseline,
                                                         StringView baseline)
    {
        auto maybe_contents = paths.get_filesystem().read_contents(path_to_baseline);
        if (auto contents = maybe_contents.get())
        {
            return parse_baseline_versions(*contents, baseline);
        }
        else if (maybe_contents.error() == std::errc::no_such_file_or_directory)
        {
            return {nullopt, expected_left_tag};
        }
        else
        {
            return Strings::format("Error: failed to read file `%s`: %s",
                                   fs::u8string(path_to_baseline),
                                   maybe_contents.error().message());
        }
    }
}

namespace vcpkg
{
    std::unique_ptr<Json::IDeserializer<std::unique_ptr<RegistryImplementation>>>
    get_registry_implementation_deserializer(const fs::path& configuration_directory)
    {
        return std::make_unique<RegistryImplDeserializer>(configuration_directory);
    }
    std::unique_ptr<Json::IDeserializer<std::vector<Registry>>> get_registry_array_deserializer(
        const fs::path& configuration_directory)
    {
        return std::make_unique<Json::ArrayDeserializer<RegistryDeserializer>>(
            "an array of registries", RegistryDeserializer(configuration_directory));
    }

    std::unique_ptr<RegistryImplementation> Registry::builtin_registry(std::string&& baseline)
    {
        return std::make_unique<BuiltinRegistry>(std::move(baseline));
    }

    Registry::Registry(std::vector<std::string>&& packages, std::unique_ptr<RegistryImplementation>&& impl)
        : packages_(std::move(packages)), implementation_(std::move(impl))
    {
        Checks::check_exit(VCPKG_LINE_INFO, implementation_ != nullptr);
    }

    RegistrySet::RegistrySet() : default_registry_(Registry::builtin_registry()), registries_() { }

    const RegistryImplementation* RegistrySet::registry_for_port(StringView name) const
    {
        for (const auto& registry : registries())
        {
            const auto& packages = registry.packages();
            if (std::find(packages.begin(), packages.end(), name) != packages.end())
            {
                return &registry.implementation();
            }
        }
        return default_registry();
    }

    Optional<VersionT> RegistrySet::baseline_for_port(const VcpkgPaths& paths, StringView port_name) const
    {
        auto impl = registry_for_port(port_name);
        if (!impl) return nullopt;
        return impl->get_baseline_version(paths, port_name);
    }

    void RegistrySet::add_registry(Registry&& r) { registries_.push_back(std::move(r)); }

    void RegistrySet::set_default_registry(std::unique_ptr<RegistryImplementation>&& r)
    {
        default_registry_ = std::move(r);
    }
    void RegistrySet::set_default_registry(std::nullptr_t) { default_registry_.reset(); }

    void RegistrySet::experimental_set_builtin_registry_baseline(StringView baseline) const
    {
        // to check if we should warn
        bool default_registry_is_builtin = false;
        if (auto builtin_registry = dynamic_cast<BuiltinRegistry*>(default_registry_.get()))
        {
            default_registry_is_builtin = true;
            builtin_registry->m_baseline_identifier.assign(baseline.begin(), baseline.end());
        }

        if (!default_registry_is_builtin || registries_.size() != 0)
        {
            System::print2(System::Color::warning,
                           "Warning: when using the registries feature, one should not use `\"$x-default-baseline\"` "
                           "to set the baseline.\n",
                           "    Instead, use the \"baseline\" field of the registry.");
        }

        for (auto& reg : registries_)
        {
            if (auto builtin_registry = dynamic_cast<BuiltinRegistry*>(reg.implementation_.get()))
            {
                builtin_registry->m_baseline_identifier.assign(baseline.begin(), baseline.end());
            }
        }
    }

    bool RegistrySet::has_modifications() const
    {
        if (!registries_.empty())
        {
            return true;
        }
        if (auto builtin_reg = dynamic_cast<const BuiltinRegistry*>(default_registry_.get()))
        {
            if (builtin_reg->m_baseline_identifier.empty())
            {
                return false;
            }
            return true;
        }
        // default_registry_ is not a BuiltinRegistry
        return true;
    }
}
